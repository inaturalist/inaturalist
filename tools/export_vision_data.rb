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
  opt :min_validation, "
    Minimum number of validation photos per species. Training and test will be
    scaled relative to this value.
  ", type: :integer, default: 4, short: "-m"
  opt :skip_augmented, "Skip export of augmented_test photos", type: :boolean, default: false
  opt :species_ids, "Only look at these species IDs. Mainly for testing", type: :integers
  opt :debug, "Print lots of crap", type: :boolean
end

START = Time.now
num_unique_users = OPTS.users
conn = ActiveRecord::Base.connection
minimum_validation_count = OPTS.min_validation
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

if OPTS.species_ids
  target_taxon_ids = OPTS.species_ids
else
  # show species and lower with observations by at least a certain number of
  # different people
  target_taxa_sql = <<-SQL
    SELECT
      t.id AS taxon_id
    FROM
      taxa t
        LEFT OUTER JOIN observations o ON o.taxon_id = t.id
    WHERE
      t.rank_level <= 10
      AND o.quality_grade = 'research'
      AND t.rank != 'hybrid'
    GROUP BY
      t.id
    HAVING
      COUNT( DISTINCT o.user_id ) >= #{num_unique_users}
  SQL
  log "Collecting IDs for taxa observed by at least #{num_unique_users} people... "
  target_taxon_ids = run_with_timing( :query_target_taxa ) do
    run_sql( target_taxa_sql ).map{ |r| r["taxon_id"].to_i }.sort
  end
end
log "Collected #{target_taxon_ids.size} taxon IDs"

target_species_ids = Set.new
tmpdir_path = Dir.mktmpdir
photos_path = File.join( tmpdir_path, "photos.csv" )
totals = { test: 0, validation: 0, training: 0, augmented_test: 0 }
species_ids = Set.new
taxon_batch_size = 20
CSV.open( photos_path, "wb" ) do |csv|
  csv << %w(photo_id set species_id taxon_id observation_id user_id url)
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
        p.small_url
      FROM
        observation_photos op
          JOIN observations o ON op.observation_id = o.id
          JOIN photos p ON op.photo_id = p.id
          JOIN taxon_ancestors ta ON ta.taxon_id = o.taxon_id
          JOIN taxa taa ON taa.id = ta.ancestor_taxon_id AND taa.rank = 'species'
      WHERE
        o.quality_grade IN ( 'research', 'needs_id' )
        AND taa.id IN (#{group.join( "," )})
    SQL
    # For each species...
    log "Querying photos for #{taxon_batch_size} taxa starting with #{group[0]}"
    rows_by_species = run_with_timing( :query_photos ) do
      run_sql( sql ).group_by{ |r| r["species_id"].to_i }
    end
    rows_by_species.each do |species_id, rows|
      next unless rows.size > 5 * minimum_validation_count
      log "Target Species #{species_id}, #{rows.size} photos total"
      target_species_ids << species_id
      # Randomly assign user_ids to sets
      test_remainder, training_remainder, validation_remainder = ( 0..2 ).to_a.shuffle
      # log "\ttest_remainder: #{test_remainder}, training_remainder: #{training_remainder}, validation_remainder: #{validation_remainder}"
      photosets = {
        test: [],
        validation: [],
        training: []
      }
      # For each photo of this species, assign it to a set based on the user
      rows.each do |r|
        id = r["id"].to_i
        user_id = r["user_id"].to_i
        quality_grade = r["quality_grade"]
        taxon_id = r["taxon_id"].to_i
        if quality_grade == "research" && user_id % 3 == test_remainder
          photosets[:test] << r
        elsif user_id % 3 == training_remainder
          photosets[:training] << r
        elsif user_id % 3 == validation_remainder
          photosets[:validation] << r
        end
      end      
      # sample the sets so they're in the right ratios
      log "\tPre-sampling:  #{photosets.map{|set, photos| "#{photos.size} #{set}"}.join( ", " )}"
      max_count = [
        photosets[:test].size,
        photosets[:training].size
      ].min.floor
      min_count = [
        max_count / 2.0,
        photosets[:validation].size
      ].min.floor
      if min_count < max_count / 2.0
        max_count = 2 * min_count
      end
      log "\tmin_count: #{min_count}, max_count: #{max_count}"
      if min_count < minimum_validation_count # must have at least 4 validation
        log "\tLess than #{minimum_validation_count} validation photos, skipping"
        next
      end
      set_without_enough_photos = photosets.detect do |set, photos|
        sample_size = set == :validation ? min_count : max_count
        photos.size < sample_size
      end
      if set_without_enough_photos
        log "\tNot enough photos for #{set_without_enough_photos[0]}, skipping species #{species_id}"
        next
      end
      species_ids << species_id
      photosets.each do |set, photos|
        sample_size = set == :validation ? min_count : max_count
        sample = photos.sample( sample_size )
        if OPTS.debug
          log "\t#{set.to_s.ljust(10)} sample_size: #{sample_size}, sample.size: #{sample.size}, photos.size: #{photos.size}"
        end
        sample.each do |photo|
          photo_url = photo["medium_url"].blank? ? photo["small_url"] : photo["medium_url"]
          next unless photo_url
          totals[set] += 1
          csv << [
            photo["photo_id"],
            set,
            photo["species_id"],
            photo["taxon_id"],
            photo["observation_id"],
            photo["user_id"],
            photo_url
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
      t.id AS taxon_id
    FROM
      taxa t
        LEFT OUTER JOIN observations o ON o.taxon_id = t.id
    WHERE
      t.rank_level <= 10
      AND o.quality_grade = 'research'
    GROUP BY
      t.id
    HAVING
      COUNT( DISTINCT o.user_id ) < #{num_unique_users}
  SQL
  log "Collecting IDs for taxa observed by less than #{num_unique_users} people... "
  non_target_taxon_ids = run_with_timing( :query_non_target_taxa) do
    run_sql( non_target_species_sql ).map{ |r| r["taxon_id"].to_i }.shuffle
  end
  log "Collected #{non_target_taxon_ids.size} taxon IDs"
  # Iterate over non-target taxa and collect observation photo IDs until you have as many as the test group
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
          p.small_url
        FROM
          observation_photos op
            JOIN observations o ON op.observation_id = o.id
            JOIN photos p ON op.photo_id = p.id
            JOIN taxon_ancestors ta ON ta.taxon_id = o.taxon_id
            JOIN taxa taa ON taa.id = ta.ancestor_taxon_id AND taa.rank = 'species'
        WHERE
          o.quality_grade = 'research'
          AND taa.id IN (#{group.join( "," )})
      SQL
      non_target_photos = run_with_timing( :query_non_target_photos ) do
        run_sql( non_target_test_sql )
      end
      non_target_photos.each do |photo|
        next if totals[:augmented_test] >= totals[:test]
        photo_url = photo["medium_url"].blank? ? photo["small_url"] : photo["medium_url"]
        totals[:augmented_test] += 1
        csv << [
          photo["photo_id"],
          "augmented_test",
          photo["species_id"],
          photo["taxon_id"],
          photo["observation_id"],
          photo["user_id"],
          photo_url
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
species_ids.to_a.in_groups_of( 500 ) do |group|
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
    Target Species. Photos in "validation" and "training" are all photos of the
    Target Species by users not represented in the "test" set from observations
    in the "Needs ID" or "Research Grade" categories. Photos in the
    "augmented_test" set are from Research Grade observations by any user of
    taxa *not* in the Target Species. "test," "validation," and "training" have
    been sampled such that they're in a rougle 2:1:2 ratio, with a minimum of
    #{minimum_validation_count} in "validation." "augmented_test" photos have
    been capped at the total number of test photos. For definitions of quality
    grades, see http://www.inaturalist.org/pages/help#quality
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
#{species_ids.size}

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
