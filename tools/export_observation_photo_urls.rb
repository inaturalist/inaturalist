# frozen_string_literal: true

# Exports a download manifest of photo URLs for every observation that has a
# value for any of the given observation fields.
#
# Output is in Google's TsvHttpData-1.0 format (consumed by Cloud Storage
# Transfer Service): a "TsvHttpData-1.0" header line followed by one URL per
# line, e.g.
#
#   TsvHttpData-1.0
#   https://inaturalist-open-data.s3.amazonaws.com/photos/1000036/large.jpg
#   https://inaturalist-open-data.s3.amazonaws.com/photos/100003895/large.jpeg
#
# Photos that would render a placeholder instead of the real image (unresolved
# flags, hidden by a moderator, still processing) are skipped, as are photos
# already emitted earlier in the run.
#
# This whole file can be pasted into the Rails console. It only defines the
# class; command line options are parsed when it is run as a script.
#
# In the Rails console:
#
#   ObservationPhotoUrlExporter.export( [7498, 325] )
#   ObservationPhotoUrlExporter.export( "7498,325", path: "/tmp/photos.tsv", size: "medium", debug: true )
#
#   # or hold on to the exporter to size up the run before writing anything
#   exporter = ObservationPhotoUrlExporter.new( 7498 )
#   exporter.count_estimate
#   exporter.export
#
# From the command line:
#
#   rails runner tools/export_observation_photo_urls.rb --observation-field-ids 7498,325
#   rails runner tools/export_observation_photo_urls.rb -o 7498 -s medium -f ~/photos.tsv --debug

require "set"
require "tmpdir"
require "fileutils"

class ObservationPhotoUrlExporter
  TSV_HEADER = "TsvHttpData-1.0"
  DEFAULT_SIZE = "large"
  DEFAULT_BATCH_ID_SPAN = 100_000

  PLUCK_COLUMNS = %w[
    photos.id
    file_prefixes.prefix
    file_extensions.extension
  ].freeze

  attr_reader :observation_field_ids, :path, :size, :open_data_only, :batch_id_span, :debug

  # Writes the manifest and returns the path it was written to.
  def self.export( observation_field_ids, **options )
    new( observation_field_ids, **options ).export
  end

  # observation_field_ids accepts an Array of ids, a single id, or a
  # comma-separated String, so it reads well from either the console or ARGV.
  def initialize( observation_field_ids, path: nil, size: DEFAULT_SIZE, open_data_only: false,
    batch_id_span: DEFAULT_BATCH_ID_SPAN, debug: false )
    @observation_field_ids = normalize_field_ids( observation_field_ids )
    @size = size.to_s.downcase
    @open_data_only = open_data_only
    @batch_id_span = batch_id_span.to_i
    @debug = debug
    validate!
    @path = path || default_path
  end

  # Writes the manifest and returns the path it was written to.
  def export
    start = Time.now
    count = 0
    seen_photo_ids = Set.new
    min_id, max_id = id_bounds

    puts "Exporting #{size} photo urls for observation fields #{observation_field_ids.join( ', ' )} " \
      "(observation_field_values.id #{min_id}..#{max_id}, id span=#{batch_id_span}) -> #{path}"

    File.open( path, "w" ) do | file |
      file.puts TSV_HEADER

      chunk_start_id = min_id
      while chunk_start_id <= max_id
        chunk_id_below = chunk_start_id + batch_id_span

        photo_rows( chunk_start_id, chunk_id_below ).each do | photo_id, prefix, extension |
          next unless seen_photo_ids.add?( photo_id )

          file.puts "#{prefix}/#{photo_id}/#{size}.#{extension}"
          count += 1
        end

        if debug
          puts "  observation_field_values.id #{chunk_start_id}..#{chunk_id_below - 1}: " \
            "#{count} urls written (#{( Time.now - start ).round}s elapsed)"
        end
        chunk_start_id = chunk_id_below
      end
    end

    puts "Done: #{count} urls -> #{path} (#{( Time.now - start ).round}s)"
    puts "Max observation_field_values.id seen: #{max_id}"
    path
  end

  # Rows the export would emit before duplicate photos are dropped. Handy for
  # sizing up a run from the console, but it scans the whole join, so it is not
  # cheap on a large set of fields.
  def count_estimate
    scope.count
  end

  # Mirrors Observation#publicly_viewable_observation_photos in SQL. An
  # unresolved flag or a HIDE moderator action makes Photo#sized_url return a
  # placeholder image (and hidden photos get a private S3 ACL, so the real URL
  # 403s). The inner joins on file_prefixes/file_extensions drop still-processing
  # photos, since Photo#processing? is file_prefix.nil?.
  def scope
    relation = field_value_scope.
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

    return relation unless open_data_only

    relation.where( "file_prefixes.prefix LIKE ?", "%#{LocalPhoto.s3_bucket( true )}%" )
  end

  private

  def normalize_field_ids( ids )
    Array( ids ).
      flat_map {| id | id.to_s.split( "," ) }.
      map {| id | id.strip.to_i }.
      uniq.
      reject( &:zero? )
  end

  def validate!
    if observation_field_ids.empty?
      raise ArgumentError, "observation_field_ids must be one or more ObservationField ids"
    end

    missing = observation_field_ids - ObservationField.where( id: observation_field_ids ).pluck( :id )
    unless missing.empty?
      raise ArgumentError, "no ObservationField with id #{missing.join( ', ' )}"
    end

    unless LocalPhoto::SIZES.map( &:to_s ).include?( size )
      raise ArgumentError, "size must be one of #{LocalPhoto::SIZES.join( ', ' )}"
    end

    raise ArgumentError, "batch_id_span must be positive" unless batch_id_span.positive?
  end

  def default_path
    work_path = Dir.mktmpdir
    FileUtils.mkdir_p work_path, mode: 0o755
    File.join( work_path, "observation_photo_urls_#{observation_field_ids.join( '-' )}_#{size}.tsv" )
  end

  def field_value_scope
    ObservationFieldValue.where( observation_field_id: observation_field_ids )
  end

  # Bound the id windows off the bare observation_field_values scope so both
  # aggregates ride index_observation_field_values_on_observation_field_id_and_id
  # instead of running the whole join.
  def id_bounds
    [field_value_scope.minimum( :id ).to_i, field_value_scope.maximum( :id ).to_i]
  end

  def photo_rows( chunk_start_id, chunk_id_below )
    scope.
      where( "observation_field_values.id >= ?", chunk_start_id ).
      where( "observation_field_values.id < ?", chunk_id_below ).
      pluck( *PLUCK_COLUMNS )
  end
end

# Only when run as a script. `rails runner` sets $0 to the file path and
# Kernel.loads it, so this is false when the file is pasted into the console.
if __FILE__ == $PROGRAM_NAME
  require "rubygems"
  require "optimist"

  opts = Optimist.options do
    banner <<~HELP
      Exports a TsvHttpData-1.0 download manifest of photo URLs for every
      observation that has a value for any of the given observation fields.

      Usage:

        rails runner tools/export_observation_photo_urls.rb --observation-field-ids 7498,325

        rails runner tools/export_observation_photo_urls.rb -o 7498 -s medium \\
          -f ~/interaction_photos.tsv --debug

      where [options] are:
    HELP
    opt :observation_field_ids, "Comma-separated ObservationField ids to export photos for",
      type: :string, short: "-o", required: true
    opt :size, "Photo size to export", type: :string, short: "-s",
      default: ObservationPhotoUrlExporter::DEFAULT_SIZE
    opt :file, "Where to write output. Default will be a tmp path.", type: :string, short: "-f"
    opt :open_data_only, "Only export photos hosted in the open data bucket", type: :boolean
    opt :batch_id_span, "Number of observation_field_value ids to scan per batch window",
      type: :integer, default: ObservationPhotoUrlExporter::DEFAULT_BATCH_ID_SPAN
    opt :debug, "Print debug statements", type: :boolean, short: "-d"
  end

  begin
    ObservationPhotoUrlExporter.export(
      opts[:observation_field_ids],
      path: opts[:file],
      size: opts[:size],
      open_data_only: opts[:open_data_only],
      batch_id_span: opts[:batch_id_span],
      debug: opts[:debug]
    )
  rescue ArgumentError => e
    Optimist.die e.message
  end
end
