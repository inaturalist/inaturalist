require 'rubygems'
require 'trollop'

headers = %w(photo_id set species_id taxon_id user_id url)

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
end

START = Time.now
num_unique_users = OPTS.users

def log( msg )
  puts "[#{(Time.now - START).round}s] #{msg}"
end

# show species and lower with observations by at least a certain number of
# different people
species_sql = <<-SQL
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
    COUNT( DISTINCT o.user_id ) >= #{num_unique_users}
SQL

log "Collecting IDs for taxa observed by at least #{num_unique_users} people... "
taxon_ids = Observation.connection.execute( species_sql ).map{ |r| r["taxon_id"].to_i }
log "Collected #{taxon_ids.size} taxon IDs"

# Make absolutely sure these photos are unique within a set
total_observation_photo_ids = {
  test: Set.new,
  training: Set.new,
  validation: Set.new
}
# Randomly choose remainders for different sets so we can assign photos to sets
# by user_id % 3
remainders = (0..4).to_a.shuffle
test_remainders = remainders[0..1] # 40% of observers which will roughly equate to 40% of observations... roughly
training_remainders = [remainders[3]]
validation_remainders = [remainders[4]]
taxon_ids.in_groups_of( 500 ) do |group|
  group.compact!
  # Test photos must be Research Grade and by users in the test group
  test_sql = <<-SQL
    SELECT
      op.id
    FROM
      observation_photos op
        JOIN observations o ON op.observation_id = o.id
    WHERE
      o.user_id % 5 IN (#{test_remainders.join( "," )})
      AND o.quality_grade = 'research'
      AND o.taxon_id IN (#{group.join( "," )})
  SQL
  log "Collecting test observation photo IDs for group starting with #{group[0]}..."
  total_observation_photo_ids[:test].merge( ActiveRecord::Base.connection.execute( test_sql ).map{ |r| r["id"].to_i } )
  # Training and validation photos must be verifiable and by users not in the
  # test group
  training_and_validation_sql = <<-SQL
    SELECT
      op.id,
      o.user_id
    FROM
      observation_photos op
        JOIN observations o ON op.observation_id = o.id
    WHERE
      o.user_id % 5 IN (#{(training_remainders + validation_remainders).flatten.join( "," )})
      AND o.quality_grade IN ( 'research', 'needs_id' )
      AND o.taxon_id IN (#{group.join( "," )})
  SQL
  log "Collecting training and validation photos for group starting with #{group[0]}..."
  # Assign training and validation photos to their sets based on user ID
  ActiveRecord::Base.connection.execute( training_and_validation_sql ).map do |r|
    id = r["id"].to_i
    user_id = r["user_id"].to_i
    if training_remainders.include?( user_id % 5 )
      total_observation_photo_ids[:training] << id
    elsif validation_remainders.include?( user_id % 5 )
      total_observation_photo_ids[:validation] << id
    end
  end
end

observation_photo_ids = {
  test: total_observation_photo_ids[:test].to_a,
  training: total_observation_photo_ids[:training].to_a,
  validation: total_observation_photo_ids[:validation].to_a
}

puts
log "Totals: #{total_observation_photo_ids.map { |set, ids| "#{ids.size} #{set}" }.join( ", " )}"
puts
total_observation_photo_ids = nil

log "Collecting augmented_test data with photos of non-target taxa"
num_test = observation_photo_ids[:test].size
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
non_target_taxon_ids = Observation.connection.execute( non_target_species_sql ).map{ |r| r["taxon_id"].to_i }.shuffle
log "Collected #{non_target_taxon_ids.size} taxon IDs"
augmented_test_observation_photo_ids = Set.new
# Iterate over non-target taxa and collect observation photo IDs until you have as many as the test group
non_target_taxon_ids.in_groups_of( 500 ) do |group|
  log "augmented_test_observation_photo_ids.size: #{augmented_test_observation_photo_ids.size}, num_test: #{num_test}"
  next if augmented_test_observation_photo_ids.size > num_test
  group.compact!
  log "Collecting non-target test observation photo IDs for group starting with #{group[0]}..."
  non_target_test_sql = <<-SQL
    SELECT
      op.id
    FROM
      observation_photos op
        JOIN observations o ON op.observation_id = o.id
    WHERE
      o.user_id % 5 IN (#{test_remainders.join( "," )})
      AND o.quality_grade = 'research'
      AND o.taxon_id IN (#{group.join( "," )})
  SQL
  augmented_test_observation_photo_ids.merge( ActiveRecord::Base.connection.execute( non_target_test_sql ).map{ |r| r["id"].to_i } )
end
observation_photo_ids[:augmented_test] = augmented_test_observation_photo_ids.to_a.sample( num_test )

puts
log "Exporting #{observation_photo_ids.map { |set, ids| "#{ids.size} #{set}" }.join( ", " )}"
tmpdir_path = Dir.mktmpdir
photos_path = File.join( tmpdir_path, "photos.csv" )
species_ids = Set.new
# Note that I tried doing this with psql instead of AR and it was actually
# slower, probably b/c of the join. This still seems like the slowest part,
# though.
CSV.open( photos_path, "wb" ) do |csv|
  csv << headers
  observation_photo_ids.each do |set, ids|
    ids.sort.in_groups_of( 500 ) do |group|
      log "Exporting #{set} observation photos starting with #{group[0]}..."
      ObservationPhoto.where( id: group ).includes( :photo, observation: :taxon ).each do |op|
        next unless op.photo
        next unless op.observation
        species_id = if op.observation.taxon.species?
          op.observation.taxon_id
        else
          op.observation.taxon.species.try(:id)
        end
        next unless species_id
        species_ids << species_id unless set.to_s == "augmented_test"
        csv << [
          op.photo_id,
          set,
          species_id,
          op.observation.taxon_id,
          op.observation.user_id,
          op.photo.best_url( "medium" )
        ]
      end
    end
  end
end

log "Exporting species"
species_path = File.join( tmpdir_path, "target_species.csv" )
CSV.open( species_path, "wb" ) do |csv|
  csv << %w(species_id name)
end
species_ids.to_a.in_groups_of( 500 ) do |group|
  group.compact!
  sql = "COPY (SELECT id AS species_id, name FROM taxa WHERE id IN (#{group.join( "," )})) TO STDOUT WITH CSV"
  system "psql #{ActiveRecord::Base.connection.current_database} -c \"#{sql}\" >> #{species_path}"
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
    Photos in the "test" set constitute roughly 40% of all photos from Research
    Grade observations of the Target Species. Photos in "validation" and
    "training" are all photos of the Target Species by users not represented in
    the "test" set from observations in Needs ID or Research Grade. Photos in
    the "augmented_test" set are from Research Grade observations by any user of
    taxa *not* in the Target Species. For definitions of these terms see
    http://www.inaturalist.org/pages/help#quality
  species_id
    Unique identifier for the species in the photo. This
    will be the same for two different photos of two different subspecies nested
    within the same species.
  taxon_id
    Unique identifier for the taxon in the photo. This will
    be different for two different photos of two different subspecies nested
    within the same species.
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
#{observation_photo_ids.map { |set, ids| "#{ids.size} #{set}" }.join( "\n" )}

Target Species:
#{species_ids.size}

Generated #{Time.now}
  EOT
end

log "Zipping up files"
archive_path = File.absolute_path( OPTS.file )
system "cd #{tmpdir_path} && tar cvzf #{archive_path} *"

puts
log "Done: #{File.absolute_path( OPTS.file )}"
puts
