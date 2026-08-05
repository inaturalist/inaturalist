# frozen_string_literal: true

require "rubygems"
require "optimist"

OPTS = Optimist.options do
  banner <<~HELP
    Exports a download manifest of photo URLs for every observation that has a
    value for any of the given observation fields.

    Output is in Google's TsvHttpData-1.0 format (consumed by Cloud Storage
    Transfer Service): a "TsvHttpData-1.0" header line followed by one URL per
    line, e.g.

      TsvHttpData-1.0
      https://inaturalist-open-data.s3.amazonaws.com/photos/1000036/medium.jpg
      https://inaturalist-open-data.s3.amazonaws.com/photos/100003895/medium.jpeg

    Photos that would render a placeholder instead of the real image (unresolved
    flags, hidden by a moderator, still processing) are skipped, as are photos
    already emitted earlier in the run.

    Usage:

      rails runner tools/export_observation_photo_urls.rb --observation-field-ids 39,1234

      rails runner tools/export_observation_photo_urls.rb -o 39 -s large \\
        -f ~/interaction_photos.tsv --debug

    where [options] are:
  HELP
  opt :observation_field_ids, "Comma-separated ObservationField ids to export photos for",
    type: :string, short: "-o", required: true
  opt :size, "Photo size to export", type: :string, short: "-s", default: "medium"
  opt :file, "Where to write output. Default will be a tmp path.", type: :string, short: "-f"
  opt :open_data_only, "Only export photos hosted in the open data bucket", type: :boolean
  opt :batch_id_span, "Number of observation_field_value ids to scan per batch window",
    type: :integer, default: 100_000
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
end

require "set"

field_ids = OPTS.observation_field_ids.to_s.split( "," ).map {| id | id.strip.to_i }.uniq.reject( &:zero? )
Optimist.die :observation_field_ids, "must be a comma-separated list of ObservationField ids" if field_ids.empty?

missing_field_ids = field_ids - ObservationField.where( id: field_ids ).pluck( :id )
unless missing_field_ids.empty?
  Optimist.die :observation_field_ids, "no ObservationField with id #{missing_field_ids.join( ', ' )}"
end

size = OPTS.size.to_s.downcase
unless LocalPhoto::SIZES.map( &:to_s ).include?( size )
  Optimist.die :size, "must be one of #{LocalPhoto::SIZES.join( ', ' )}"
end

start = Time.now
work_path = Dir.mktmpdir
FileUtils.mkdir_p work_path, mode: 0o755
out_path = OPTS.file || File.join( work_path, "observation_photo_urls_#{field_ids.join( '-' )}_#{size}.tsv" )

# Mirrors Observation#publicly_viewable_observation_photos in SQL. An unresolved
# flag or a HIDE moderator action makes Photo#sized_url return a placeholder
# image (and hidden photos get a private S3 ACL, so the real URL 403s). The inner
# joins on file_prefixes/file_extensions drop still-processing photos, since
# Photo#processing? is file_prefix.nil?.
scope = ObservationFieldValue.
  where( observation_field_id: field_ids ).
  joins( "JOIN observation_photos op ON op.observation_id = observation_field_values.observation_id" ).
  joins( "JOIN photos ON photos.id = op.photo_id" ).
  joins( "JOIN file_prefixes ON file_prefixes.id = photos.file_prefix_id" ).
  joins( "JOIN file_extensions ON file_extensions.id = photos.file_extension_id" ).
  # a blank prefix or extension would compose a malformed URL
  where( "file_prefixes.prefix != '' AND file_extensions.extension != ''" ).
  where( <<~SQL ).
    NOT EXISTS (
      SELECT 1 FROM flags f
      WHERE f.flaggable_type = 'Photo' AND f.flaggable_id = photos.id AND f.resolved = false
    )
  SQL
  where( <<~SQL )
    NOT EXISTS (
      SELECT 1 FROM moderator_actions ma
      WHERE ma.resource_type = 'Photo' AND ma.resource_id = photos.id
        AND ma.action = '#{ModeratorAction::HIDE}'
        AND ma.id = (
          SELECT MAX( ma2.id ) FROM moderator_actions ma2
          WHERE ma2.resource_type = 'Photo' AND ma2.resource_id = photos.id
        )
    )
  SQL

if OPTS.open_data_only
  scope = scope.where( "file_prefixes.prefix LIKE ?", "%#{LocalPhoto.s3_bucket( true )}%" )
end

PLUCK_COLUMNS = %w[
  photos.id
  file_prefixes.prefix
  file_extensions.extension
].freeze

count = 0
chunk_size = OPTS.batch_id_span
# Bound the id windows off the bare observation_field_values scope so both
# aggregates ride index_observation_field_values_on_observation_field_id_and_id
# instead of running the whole join.
field_value_scope = ObservationFieldValue.where( observation_field_id: field_ids )
min_id = field_value_scope.minimum( :id ).to_i
max_id = field_value_scope.maximum( :id ).to_i
seen_photo_ids = Set.new

puts "Exporting #{size} photo urls for observation fields #{field_ids.join( ', ' )} " \
     "(observation_field_values.id #{min_id}..#{max_id}, id span=#{chunk_size}) -> #{out_path}"

File.open( out_path, "w" ) do | file |
  file.puts "TsvHttpData-1.0"

  chunk_start_id = min_id
  while chunk_start_id <= max_id
    chunk_id_below = chunk_start_id + chunk_size
    rows = scope.
      where( "observation_field_values.id >= ?", chunk_start_id ).
      where( "observation_field_values.id < ?", chunk_id_below ).
      pluck( *PLUCK_COLUMNS )

    rows.each do | photo_id, prefix, extension |
      next unless seen_photo_ids.add?( photo_id )

      file.puts "#{prefix}/#{photo_id}/#{size}.#{extension}"
      count += 1
    end

    if OPTS.debug
      puts "  observation_field_values.id #{chunk_start_id}..#{chunk_id_below - 1}: " \
           "#{count} urls written (#{( Time.now - start ).round}s elapsed)"
    end
    chunk_start_id += chunk_size
  end
end

puts "Done: #{count} urls -> #{out_path} (#{( Time.now - start ).round}s)"
puts "Max observation_field_values.id seen: #{max_id}"
