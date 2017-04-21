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
  opt :debug, "Print lots of crap", type: :boolean
end

START = Time.now
num_unique_users = OPTS.users
TIMING = {}

def log( msg )
  puts "[#{(Time.now - START).round}s] #{msg}"
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

# If species_ids passed in as a param just use those
if OPTS.species_ids
  target_taxon_ids = OPTS.species_ids
else
  # Select species with observations by at least a certain number of different
  # people. Photos of infraspecies will get included later when we query on
  # species
  target_species_sql = <<-SQL
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
      COUNT( DISTINCT o.user_id ) >= #{num_unique_users}
  SQL
  log "Collecting IDs for taxa observed by at least #{num_unique_users} people... "
  target_taxon_ids = run_with_timing( :query_target_species ) do
    run_sql( target_species_sql ).map{ |r| r["taxon_id"].to_i }.sort
  end
end
log "Collected #{target_taxon_ids.size} taxon IDs"

tmpdir_path = Dir.mktmpdir
photos_path = File.join( tmpdir_path, "photos.csv" )
totals = { test: 0, validation: 0, training: 0, augmented_test: 0 }
target_species_ids = Set.new
taxon_batch_size = 20
license_numbers = ( OPTS.licenses || [] ).map{ |code| Photo.license_number_for_code( code ) }
CSV.open( photos_path, "wb" ) do |csv|
  csv << %w(photo_id set species_id taxon_id observation_id user_id url quality_grade photo_license obs_license rights_holder)
  target_taxon_ids.in_groups_of( taxon_batch_size ) do |group|
    show_timing_stats if OPTS.debug
    group.compact!
    # This is actually seems faster than loading things out of ES. Just fishing
    # out the photo IDs and then doing an id IN (...) query also isn't that
    # fast, despite using the pkey index
    sql = <<-SQL
      SELECT
        op.id,
        o.quality_grade,
        op.photo_id,
        taa.id AS species_id,
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
          JOIN observations o ON op.observation_id = o.id
          JOIN photos p ON op.photo_id = p.id
          JOIN taxon_ancestors ta ON ta.taxon_id = o.taxon_id
          JOIN taxa taa ON taa.id = ta.ancestor_taxon_id AND taa.rank = 'species'
          JOIN users u ON u.id = p.user_id
      WHERE
        o.quality_grade IN ( 'research', 'needs_id' )
        AND taa.id IN (#{group.join( "," )})
        #{"AND p.license IN (#{license_numbers.join( "," )})" unless license_numbers.blank?}
    SQL
    # For each species...
    log "Querying photos for #{taxon_batch_size} taxa starting with #{group[0]}"
    rows_by_species = run_with_timing( :query_photos ) do
      run_sql( sql ).group_by{ |r| r["species_id"].to_i }
    end
    rows_by_species.each do |species_id, rows|
      log "Target Species #{species_id}, #{rows.size} photos total"
      # Randomly assign user_ids to sets, 2/5 in training, 2/5 in test, 1/5 in validation
      photosets = {
        test: [],
        training: [],
        validation: []
      }
      number_of_rg_users = rows.map{ |r| r["quality_grade"] == "research" ? r["user_id"].to_i : nil }.compact.uniq.size
      log "\tNumber of RG users: #{number_of_rg_users}"
      desired_number_of_test_users = ( number_of_rg_users * 0.4 ).floor
      log "\tDesired number of test users: #{desired_number_of_test_users}"
      desired_number_of_training_users = desired_number_of_test_users
      desired_number_of_validation_users = ( desired_number_of_test_users / 2 ).floor
      actual_number_of_test_users = 0
      actual_number_of_training_users = 0
      actual_number_of_validation_users = 0
      # shuffle users so we assign them to sets randomly
      species_rows_by_user_id = rows.group_by{|r| r["user_id"].to_i }.to_a.shuffle
      # # Or we could try to make sure that test always has the most users, even at the expense of the other sets
      # species_rows_by_user_id = rows.group_by{|r| r["user_id"].to_i }.sort_by{ |user_id, rows| rows.size }
      species_rows_by_user_id.each do |user_id, rows|
        # Assign users to sets until we meet our desired quotas Note that
        # Grant's recommendation of 2017-02-15 was to stick to the quotas (I
        # think), but in order to avoid discarding photos we are just filling
        # the test quota and then dividing the rest between validation and
        # training
        rg_rows = rows.select{ |r| r["quality_grade"] == "research" }
        # log "\tUser #{user_id}, #{rows.size} photos, #{rg_rows.size} RG photos"
        # Fill our test quota first
        if rg_rows.size > 0 && actual_number_of_test_users < desired_number_of_test_users
          # log "\t\tAdding to test"
          photosets[:test] += rg_rows
          actual_number_of_test_users += 1
        # elsif actual_number_of_training_users < desired_number_of_training_users # this fills the training quota first
        # When test is filled, assign the rest randomly to training and validation
        elsif user_id % 2 == 0
          # log "\t\tAdding to training"
          photosets[:training] += rows
          actual_number_of_training_users += 1
        # elsif actual_number_of_validation_users < desired_number_of_validation_users # this fills the validation quota
        elsif user_id % 2 == 1
          # log "\t\tAdding to validation"
          photosets[:validation] += rows
          actual_number_of_validation_users += 1
        end
      end
      if OPTS.debug
        log "\tTest Users:        #{desired_number_of_test_users} desired, #{actual_number_of_test_users} actual"
        log "\tTraining Users:    #{desired_number_of_training_users} desired, #{actual_number_of_training_users} actual"
        log "\tValidation Users:  #{desired_number_of_validation_users} desired, #{actual_number_of_validation_users} actual"
        photosets.each do |set, photos|
          log "\t#{"#{set.to_s.capitalize} Photos:".ljust( 18 )} #{photos.size}"
        end
      end
      target_species_ids << species_id
      photosets.each do |set, photos|
        photos.each do |photo|
          photo_url = photo["medium_url"].blank? ? photo["small_url"] : photo["medium_url"]
          next unless photo_url
          photo_license_url = Photo.license_url_for_number( photo["photo_license"] )
          obs_license_url = Photo.license_url_for_code( photo["obs_license"] )
          totals[set] += 1
          csv << [
            photo["photo_id"],
            set,
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
  non_target_species_sql = <<-SQL
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
      log "totals[:test]: #{totals[:test]}, totals[:augmented_test]: #{totals[:augmented_test]}"
      next if totals[:augmented_test] >= totals[:test]
      group.compact!
      log "Collecting non-target test observation photo IDs for group starting with #{group[0]}..."
      non_target_test_sql = <<-SQL
        SELECT
          op.photo_id,
          taa.id AS species_id,
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
            JOIN observations o ON op.observation_id = o.id
            JOIN photos p ON op.photo_id = p.id
            JOIN taxon_ancestors ta ON ta.taxon_id = o.taxon_id
            JOIN taxa taa ON taa.id = ta.ancestor_taxon_id AND taa.rank = 'species'
            JOIN users u ON u.id = p.user_id
        WHERE
          o.quality_grade = 'research'
          AND taa.id IN (#{group.join( "," )})
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
images of species. It has been restricted to photos of taxa with
#{num_unique_users} or more unique observers (the Target Species). It contains
the following files:

photos.csv

Data about photos, including

  photo_id
    Unique identifier for this photo (though the same photo might appear
    multiple times for different species if used in multiple observations)
  set
    Photos in the "test" set come from "Research Grade" observations of the
    Target Species made by 40% of the users who have observed each species.
    Photos in "validation" and "training" are all photos of the Target Species
    by users not represented in the "test" set from observations in the "Needs
    ID" or "Research Grade" categories. Photos in the "augmented_test" set are
    from Research Grade observations by any user of taxa *not* in the Target
    Species. "test," "validation," and "training" have been sampled such that
    users are in a rough 2:1:2 ratio "augmented_test" photos have been capped at
    the total number of test photos. For definitions of quality grades, see
    http://www.inaturalist.org/pages/help#quality
  species_id
    Unique identifier for the species in the photo. This
    will be the same for two different photos of two different subspecies nested
    within the same species.
  taxon_id
    Unique identifier for the taxon in the photo. This will
    be different for two different photos of two different subspecies nested
    within the same species.
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
    Unique identifier for the species in the photo. This
    will be the same for two different photos of two different subspecies nested
    within the same species.
  name
    Name of this species

STATS

Photos:
#{totals.map { |set, total| "#{total} #{set}" }.join( "\n" )}

Target Species:
#{target_species_ids.size}

Generated #{Time.now}
  EOT
end

log "Zipping up files"
archive_path = File.absolute_path( OPTS.file )
system "cd #{tmpdir_path} && tar cvzf #{archive_path} *"

show_timing_stats

puts
log "Done: #{File.absolute_path( OPTS.file )}"
puts
