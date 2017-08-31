require 'rubygems'
require 'trollop'

OPTS = Trollop::options do
    banner <<-EOS

Export a CSV archive of photos suitable for use in computer vision training.
Photos are of species-or-lower taxa that have RG-quality observations by at
least a certain number of users (default is 20). Test photos represent roughly
40% of the RG-quality observations of the target species, while training and
validation photos come from verifiable observations of the target species. See
the README in the archive for more metadata.

Usage:

  rails runner tools/export_vision_data.rb

where [options] are:
EOS
  opt :file, "Where to write the archive. Default will be tmp path.", type: :string, short: "-f", default: "inaturalist-vision-data.tgz"
  opt :users, "
    User cuttoff, number of unique users that must have observed a taxon for
    photos of that taxon to be included.
    ", type: :integer, default: 20, short: "-u"
  opt :skip_augmented, "Skip export of augmented_test photos", type: :boolean, default: false
  opt :species_ids, "Only look at these species IDs. Mainly for testing", type: :integers
  opt :licenses, "Licenses to filter photos by", type: :strings
  opt :quality, "Quality of observations to use when determining the Target Species. Values: research,confirmed",
    type: :string, default: "research", short: "-q"
  opt :val_a_users_cap, "Maximum number of validation users in Species Group A", default: "20"
  opt :test_a_users_cap, "Maximum number of test users in Species Group A", default: "50"
  opt :debug, "Print lots of crap", type: :boolean
end

START = Time.now
num_unique_users = OPTS.users
TIMING = {}

candidate_observations_sql = <<-SQL
  SELECT
    observations.id,
    observations.taxon_id,
    observations.community_taxon_id,
    observations.user_id,
    observations.quality_grade,
    observations.license,
    COUNT(failing_metrics.observation_id) AS num_failing_metrics,
    COALESCE(observations.community_taxon_id, observations.taxon_id) AS joinable_taxon_id
  FROM
    observations
      LEFT OUTER JOIN (
        SELECT observation_id, metric
        FROM quality_metrics
        WHERE metric != 'wild'
        GROUP BY observation_id, metric
        HAVING count(CASE WHEN agree THEN 1 ELSE null END) < count(CASE WHEN agree THEN null ELSE 1 END)
      ) failing_metrics ON failing_metrics.observation_id = observations.id
      LEFT OUTER JOIN flags ON flags.flaggable_type = 'Observation' AND flags.flaggable_id = observations.id AND NOT flags.resolved
  WHERE
    observations.observation_photos_count > 0
    AND (observations.community_taxon_id IS NOT NULL OR observations.taxon_id IS NOT NULL)
  GROUP BY
    observations.id
  HAVING
    COUNT(failing_metrics.observation_id) = 0
    AND COUNT(flags.id) = 0
SQL

tmpdir_path = Dir.mktmpdir
log_path = File.join( tmpdir_path, "output.log" )
LOG_F = open( log_path, "w" )

def log( msg )
  out = "[#{(Time.now - START).round}s] #{msg}"
  puts out
  unless LOG_F.closed?
    LOG_F.puts out
  end
end

def run_with_timing( key )
  start = Time.now
  result = yield
  duration = Time.now - start
  if TIMING[key]
    TIMING[key][:events] = TIMING[key][:events] + 1
    TIMING[key][:avg] = ( TIMING[key][:avg] + duration ) / TIMING[key][:events]
    TIMING[key][:total] = TIMING[key][:total] + duration
  else
    TIMING[key] = { avg: duration, total: duration, events: 1 }
  end
  result
end

def run_sql( sql )
  log sql if OPTS.debug
  ActiveRecord::Base.connection.execute( sql )
end

def show_timing_stats
  puts
  log "Timing stats:"
  TIMING.each do |key, stats|
    puts "#{key}: #{stats.map{ |k,v| "#{v} #{k}"}.join( ", " )}"
  end
end


# Select species with observations by at least a certain number of different
# people. Photos of infraspecies will get included later when we query on
# species
target_species_sql_from = if OPTS.quality == "research"
  <<-SQL
    observations o
      JOIN taxon_ancestors ta ON ta.taxon_id = o.community_taxon_id
      JOIN taxa tat ON tat.id = ta.ancestor_taxon_id
      LEFT OUTER JOIN quality_metrics qm ON qm.observation_id = o.id
  SQL
else
  <<-SQL
    (
      #{candidate_observations_sql}
    ) o
      JOIN taxon_ancestors ta ON ta.taxon_id = o.joinable_taxon_id
      JOIN taxa tat ON tat.id = ta.ancestor_taxon_id
  SQL
end
target_species_sql_where = if OPTS.quality == "research"
  <<-SQL
    tat.rank = 'species'
    AND o.quality_grade = 'research'
  SQL
else
  <<-SQL
    tat.rank = 'species'
    AND o.num_failing_metrics = 0
    AND o.community_taxon_id IS NOT NULL
  SQL
end
# If species_ids passed in as a param just use those
if OPTS.species_ids
  target_species_sql_where += " AND ta.taxon_id IN (#{OPTS.species_ids.join( "," )})"
end
target_species_sql = <<-SQL
  SELECT
    ta.ancestor_taxon_id AS taxon_id,
    COUNT( DISTINCT o.user_id ) AS num_users,
    CASE
      WHEN COUNT( DISTINCT o.user_id ) >= 500 THEN 'A'
      WHEN COUNT( DISTINCT o.user_id ) BETWEEN 40 AND 500 THEN 'B'
      ELSE 'C'
    END AS species_group
  FROM
    #{target_species_sql_from}
  WHERE
    #{target_species_sql_where}
  GROUP BY
    ta.ancestor_taxon_id
  HAVING
    COUNT( DISTINCT o.user_id ) >= #{num_unique_users}
SQL
log "Collecting taxa observed by at least #{num_unique_users} people... "
target_taxon_ids = run_with_timing( :query_target_species ) do
  run_sql( target_species_sql ).map{ |r| [r["taxon_id"].to_i, r["species_group"]] }
end
log "Collected #{target_taxon_ids.size} taxon IDs"

photos_path = File.join( tmpdir_path, "photos.csv" )
totals = { test: 0, validation: 0, training: 0, augmented_test: 0 }
target_species_ids = Set.new
target_rg_observation_ids = Set.new
taxon_batch_size = 20
license_numbers = ( OPTS.licenses || [] ).map{ |code| Photo.license_number_for_code( code ) }
CSV.open( photos_path, "wb" ) do |csv|
  csv << %w(photo_id set species_group species_id taxon_id observation_id user_id url quality_grade photo_license obs_license rights_holder)
  target_taxon_ids.in_groups_of( taxon_batch_size ) do |taxon_batch|
    show_timing_stats if OPTS.debug
    taxon_batch.compact!
    taxon_batch_groups_by_taxon_id = Hash[taxon_batch]
    # This is actually seems faster than loading things out of ES. Just fishing
    # out the photo IDs and then doing an id IN (...) query also isn't that
    # fast, despite using the pkey index
    sql = <<-SQL
      SELECT
        op.id,
        o.quality_grade,
        op.photo_id,
        taa.id AS species_id,
        COALESCE(o.community_taxon_id, o.taxon_id) AS joinable_taxon_id,
        o.community_taxon_id,
        o.taxon_id AS taxon_id,
        op.observation_id,
        o.user_id,
        p.medium_url,
        p.small_url,
        p.license AS photo_license,
        o.license AS obs_license,
        COALESCE(NULLIF(u.name, ''), u.login) AS rights_holder
      FROM
        observation_photos op
          JOIN #{OPTS.quality == "research" ? "observations" : "(#{candidate_observations_sql})"} o ON op.observation_id = o.id
          JOIN photos p ON op.photo_id = p.id
          JOIN taxon_ancestors ta ON ta.taxon_id = COALESCE(o.community_taxon_id, o.taxon_id)
          JOIN taxa taa ON taa.id = ta.ancestor_taxon_id AND taa.rank = 'species'
          JOIN users u ON u.id = p.user_id
      WHERE
        taa.id IN (#{taxon_batch.map(&:first).join( "," )})
        #{"AND o.quality_grade IN ( 'research', 'needs_id' )" if OPTS.quality == "research"}
        #{"AND o.joinable_taxon_id IS NOT NULL" if OPTS.quality != "research"}
        #{"AND p.license IN (#{license_numbers.join( "," )})" unless license_numbers.blank?}
    SQL
    # For each species...
    log "Querying photos for #{taxon_batch_size} taxa starting with #{taxon_batch[0][0]}"
    rows_by_species = run_with_timing( :query_photos ) do
      run_sql( sql ).group_by{ |r| r["species_id"].to_i }
    end
    rows_by_species.each do |species_id, rows|
      species_group = taxon_batch_groups_by_taxon_id[species_id]
      log "Target Species #{species_id}, #{rows.size} photos total, Species Group: #{species_group}"
      # Randomly assign user_ids to sets, 2/5 in training, 2/5 in test, 1/5 in validation
      photosets = {
        test: [],
        training: [],
        validation: []
      }
      number_of_rg_users = if OPTS.quality == "research"
        rows.map{ |r| r["quality_grade"] == "research" ? r["user_id"].to_i : nil }.compact.uniq.size
      else
        rows.map{ |r| !r["community_taxon_id"].blank? ? r["user_id"].to_i : nil }.compact.uniq.size
      end
      number_of_users = rows.map{ |r| r["user_id"].to_i }.compact.uniq.size
      log "  Number of RG users: #{number_of_rg_users}"
      desired_number_of_test_users = case species_group
      when "A" then OPTS.test_a_users_cap.to_i
      when "B" then ( number_of_rg_users * 0.1 ).round
      else ( number_of_rg_users * 0.2 ).round
      end
      desired_number_of_test_users = 1 if desired_number_of_test_users == 0
      desired_number_of_validation_users = case species_group
      when "A" then OPTS.val_a_users_cap.to_i
      when "B" then ( number_of_users * 0.05 ).round
      else ( number_of_users * 0.1 ).round
      end
      desired_number_of_validation_users = 1 if desired_number_of_validation_users == 0
      actual_number_of_test_users = 0
      actual_number_of_training_users = 0
      actual_number_of_validation_users = 0
      # shuffle users so we assign them to sets randomly
      species_rows_by_user_id = rows.group_by{|r| r["user_id"].to_i }.to_a.shuffle
      species_rows_by_user_id.each do |user_id, rows|
        # Assign users to sets until we meet our desired quotas Note that
        # Grant's recommendation of 2017-02-15 was to stick to the quotas (I
        # think), but in order to avoid discarding photos we are just filling
        # the test quota and then dividing the rest between validation and
        # training
        rg_rows = if OPTS.quality == "research"
          rows.select{ |r| r["quality_grade"] == "research" }
        else
          rows.select{ |r| !r["community_taxon_id"].blank? }
        end
        next if rg_rows.blank? # if for some reason we're looking at a species with no RG or RG* observations, don't even bother including it
        # Fill our test quota first
        if rg_rows.size > 0 && actual_number_of_test_users < desired_number_of_test_users
          photosets[:test] += rg_rows
          actual_number_of_test_users += 1
        # When test is filled, assign to validation
        elsif actual_number_of_validation_users < desired_number_of_validation_users # this fills the validation quota
          photosets[:validation] += rows
          actual_number_of_validation_users += 1
        # When we've filled our test and validation quotas, fill up training
        else
          photosets[:training] += rows
          actual_number_of_training_users += 1
        end
      end
      log "  Test Users:        #{desired_number_of_test_users} desired, #{actual_number_of_test_users} actual"
      log "  Validation Users:  #{desired_number_of_validation_users} desired, #{actual_number_of_validation_users} actual"
      log "  Training Users:    infinite desired, #{actual_number_of_training_users} actual"
      photosets.each do |set, photos|
        log "  #{"#{set.to_s.capitalize} Photos:".ljust( 18 )} #{photos.size}"
      end
      target_species_ids << species_id
      photosets.each do |set, photos|
        photos.each do |photo|
          if OPTS.quality == "research"
            target_rg_observation_ids << photo["observation_id"].to_i if photo["quality_grade"] == "research"
          else
            target_rg_observation_ids << photo["observation_id"].to_i unless photo["community_taxon_id"].blank?
          end
          photo_url = photo["medium_url"].blank? ? photo["small_url"] : photo["medium_url"]
          next unless photo_url
          photo_license_url = Photo.license_url_for_number( photo["photo_license"] )
          obs_license_url = Photo.license_url_for_code( photo["obs_license"] )
          totals[set] += 1
          csv << [
            photo["photo_id"],
            set,
            species_group,
            photo["species_id"],
            photo["taxon_id"],
            photo["observation_id"],
            photo["user_id"],
            photo_url,
            photo["quality_grade"],
            photo_license_url,
            obs_license_url,
            photo["rights_holder"]
          ]
        end
      end
    end
  end
end

puts
log "Totals: #{totals.map { |set, total| "#{total} #{set}" }.join( ", " )}"
puts

unless OPTS.skip_augmented
  log "Collecting augmented_test data with photos of non-target taxa"
  log "Calculating desired number of augmented test photos..."
  rg_total = if OPTS.quality == "research"
    Observation.has_quality_grade( "research" ).count
  else
    run_sql( "SELECT COUNT(*) AS count from (#{candidate_observations_sql}) o WHERE o.community_taxon_id IS NOT NULL" )[0]["count"].to_i
  end
  log "  rg_total: #{rg_total}"
  rg_target_total = target_rg_observation_ids.size
  log "  rg_target_total: #{rg_target_total}"
  targeted_obs_fraction = rg_target_total.to_f / rg_total
  log "  targeted_obs_fraction: #{targeted_obs_fraction}"
  total_test_photos = totals[:test]
  log "  total_test_photos: #{total_test_photos}"
  desired_augmented_test_total = ((1 - targeted_obs_fraction) * total_test_photos / targeted_obs_fraction).to_i rescue 0
  log "  Desired Augmented Test Total: #{desired_augmented_test_total}"
  non_target_species_sql = if OPTS.quality == "research"
    <<-SQL
      SELECT
        ta.ancestor_taxon_id AS taxon_id
      FROM
        observations o
          JOIN taxon_ancestors ta ON ta.taxon_id = o.taxon_id
          JOIN taxa tat ON tat.id = ta.ancestor_taxon_id
      WHERE
        o.quality_grade = 'research'
        AND tat.rank = 'species'
      GROUP BY
        ta.ancestor_taxon_id
      HAVING
        COUNT( DISTINCT o.user_id ) < #{num_unique_users}
    SQL
  else
    <<-SQL
      SELECT
        ta.ancestor_taxon_id AS taxon_id
      FROM
        (
          #{candidate_observations_sql}
        ) o
          JOIN taxon_ancestors ta ON ta.taxon_id = o.joinable_taxon_id
          JOIN taxa tat ON tat.id = ta.ancestor_taxon_id
      WHERE
        tat.rank = 'species'
        AND o.num_failing_metrics = 0
      GROUP BY
        ta.ancestor_taxon_id
      HAVING
        COUNT( DISTINCT o.user_id ) < #{num_unique_users};
    SQL
  end
  log "Collecting IDs for taxa observed by less than #{num_unique_users} people... "
  non_target_taxon_ids = run_with_timing( :query_non_target_taxa) do
    run_sql( non_target_species_sql ).map{ |r| r["taxon_id"].to_i }.shuffle
  end
  log "Collected #{non_target_taxon_ids.size} taxon IDs"
  # Iterate over non-target taxa and collect observation photo IDs until you
  # have as many as the test group. This is not going to result in an evenly
  # distributed set of photos b/c if you end up with some highly observed
  # species early on they will dominate the augmented_test set, but shuffling
  # the taxon IDs should alleviate that a bit
  CSV.open( photos_path, "ab" ) do |csv|
    non_target_taxon_ids.in_groups_of( 500 ) do |group|
      show_timing_stats if OPTS.debug
      log "desired_augmented_test_total: #{desired_augmented_test_total}, totals[:augmented_test]: #{totals[:augmented_test]}"
      next if totals[:augmented_test] >= desired_augmented_test_total
      group.compact!
      log "Collecting non-target test observation photo IDs for group starting with #{group[0]}..."
      non_target_test_sql = <<-SQL
        SELECT
          op.photo_id,
          o.quality_grade,
          taa.id AS species_id,
          o.taxon_id AS taxon_id,
          COALESCE(o.community_taxon_id, o.taxon_id) AS joinable_taxon_id,
          op.observation_id,
          o.user_id,
          p.medium_url,
          p.small_url,
          p.license AS photo_license,
          o.license AS obs_license,
          COALESCE(NULLIF(u.name, ''), u.login) AS rights_holder
        FROM
          observation_photos op
            JOIN #{OPTS.quality == "research" ? "observations" : "(#{candidate_observations_sql})"} o ON op.observation_id = o.id
            JOIN photos p ON op.photo_id = p.id
            JOIN taxon_ancestors ta ON ta.taxon_id = COALESCE(o.community_taxon_id, o.taxon_id)
            JOIN taxa taa ON taa.id = ta.ancestor_taxon_id AND taa.rank = 'species'
            JOIN users u ON u.id = p.user_id
        WHERE
          taa.id IN (#{group.join( "," )})
          #{"AND o.quality_grade = 'research'" if OPTS.quality == "research"}
          #{"AND o.community_taxon_id IS NOT NULL" if OPTS.quality != "research"}
          #{"AND p.license IN (#{license_numbers.join( "," )})" unless license_numbers.blank?}
      SQL
      non_target_photos = run_with_timing( :query_non_target_photos ) do
        run_sql( non_target_test_sql )
      end
      non_target_photos.each do |photo|
        next if totals[:augmented_test] >= totals[:test]
        photo_url = photo["medium_url"].blank? ? photo["small_url"] : photo["medium_url"]
        photo_license_url = Photo.license_url_for_number( photo["photo_license"] )
        obs_license_url = Photo.license_url_for_code( photo["obs_license"] )
        totals[:augmented_test] += 1
        csv << [
          photo["photo_id"],
          "augmented_test",
          "D",
          photo["species_id"],
          photo["taxon_id"],
          photo["observation_id"],
          photo["user_id"],
          photo_url,
          photo["quality_grade"],
          photo_license_url,
          obs_license_url,
          photo["rights_holder"]
        ]
      end
    end
  end
end

puts
log "Totals: #{totals.map { |set, total| "#{total} #{set}" }.join( ", " )}"
puts


log "Exporting species"
species_path = File.join( tmpdir_path, "target_species.csv" )
CSV.open( species_path, "wb" ) do |csv|
  csv << %w(species_id name)
end
target_species_ids.to_a.in_groups_of( 500 ) do |group|
  group.compact!
  sql = "COPY (SELECT id AS species_id, name FROM taxa WHERE id IN (#{group.join( "," )})) TO STDOUT WITH CSV"
  dbconf = Rails.configuration.database_configuration[Rails.env]
  system "psql #{dbconf["database"]} -h #{dbconf["host"]} -c \"#{sql}\" >> #{species_path}"
end

log "Exporting README"
readme_path = File.join( tmpdir_path, "readme.txt" )
open( readme_path, "w" ) do |f|
  f << <<-EOT
INATURALIST VISION TRAINING DATA

This archive contains data for training a computer vision system to recognize
images of species. The species used for labels (the Target Species) met the
following requirements:

* observed by #{num_unique_users} or more unique observers
* used in observations that were in the Research Grade (RG) or Needs ID (NID)
  quality grade categories#{ ", or would be in those categories if they were not
  captive/cultivated or human. We will still refer to these observations as
  Research Grade and Needs ID in this README." if OPTS.quality != "research" }
#{ "* released under one of the following licenses: #{OPTS.licenses.join( ", " )}" if OPTS.licenses}

For more about some of these iNat-specific quality terms, see 
http://www.inaturalist.org/pages/help#quality

Species are partitioned into Species Groups based on the number of users that
observed them:

A: >= 500 people with RG observations
B: >= 40 AND < 500 people with RG observations
C: >= 10 AND < 40 people with RG observations
D: not in the Target Species set (see Augmented Test below)

Photos are categorized into "Sets" which can be used for test, validation, and
training. Photos are partitioned by user such that no photographer can
contribute to more than one set per species. The number of users contributing to
a Set for a given taxon is determined by the taxon's Species Group:

* Test: photos from Research Grade observations.
  * Species Group A: photos by at most #{OPTS.test_a_users_cap}
  * Species Group B: photos by 10% of RG users
  * Species Group C: photos by 20% of RG users
* Validation: photos from Research Grade OR Needs ID observations
  * Species Group A: photos by at most #{OPTS.val_a_users_cap}
  * Species Group B: photos by 5% of RG AND NID users
  * Species Group C: photos by 10% of RG AND NID users
* Training: photos from Research Grade OR Needs ID observations
  * No group restrictions, just receives photos by users not in Test or
    Validation
* Augmented Test: photos of species not in the Target Species, i.e. species we
  didn't feel we had an adequate amount of data to train a CV model. These data
  can be used to determine how the model performs on species it hasn't seen.
  Number of photos is determined as follows:
  * a = the total number of RG* observations
  * b = the total number of RG* obs for species with >= 10 RG* obs users
  * c = b / a = fraction of RG* obs represented by labels
  * d = the total number of Test photos
  * e = (1 - c) * d / c = the number of photos we need for Augmented Test

The archive contains the following files:

photos.csv

Data about photos, including

  photo_id
    Unique identifier for this photo (though the same photo might appear
    multiple times for different species if used in multiple observations)
  set
    Set this photo belongs to, i.e. test, validation, training, or
    augmented_test
  species_group
    Species Group the species in this photo belongs to (see above).
  species_id
    Unique identifier for the species in the photo. This will be the same for
    two different photos of two different subspecies nested within the same
    species.
  taxon_id
    Unique identifier for the taxon in the photo. This will be different for
    two different photos of two different subspecies nested within the same
    species.
  observation_id
    Unique identifier for the observation associated with this photo. An
    observation represents an event in which a person witnessed evidence for the
    presence of an organism, and can have many photos. Rarely, the same photo
    will be used in multiple observations if the photo depicts multiple
    organisms.
  user_id
    Unique identifier of the user who uploaded the photo.
  url
    URL of the medium-sized version of the photo, usually about 500 px on the
    long edge.
  quality_grade
    iNaturalist quality grade. For definitions of quality grades, see
    http://www.inaturalist.org/pages/help#quality
  photo_license
    URL for the license applied to this image, if any license.
  obs_license
    URL for the license applied to the observation.
  rights_holder
    Legal rights holder for this image, suitable for use in attribution to
    comply with Creative Commons licenses.

target_species.csv

Data about the Target Species described in this archive (i.e. species with
#{num_unique_users} or more unique observers), including

  species_id
    Unique identifier for the species in the photo. This will be the same for
    two different photos of two different subspecies nested within the same
    species. This is the iNat taxon ID, so you should always be able to look up
    the corresponding iNat taxon: http://www.inaturalist.org/taxa/43584
  name
    Name of this species

output.log

Log output from data export, mostly for debugging.

STATS

Photos:
#{totals.map { |set, total| "#{total} #{set}" }.join( "\n" )}

Target Species:
#{target_species_ids.size}

OPTS

#{OPTS.map{|k,v| "#{k}: #{v}"}.join( "\n" )}

Generated #{Time.now}
  EOT
end

LOG_F.close

log "Zipping up files"
archive_path = File.absolute_path( OPTS.file )
system "cd #{tmpdir_path} && tar cvzf #{archive_path} *"

show_timing_stats

puts
log "Done: #{File.absolute_path( OPTS.file )}"
puts
