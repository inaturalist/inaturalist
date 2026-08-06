# frozen_string_literal: true

# Exports a download manifest of photo URLs for observations that have exactly
# one photo, for running a perceptual hash over the images to find the same
# picture attached to more than one observation.
#
# Output is in Google's TsvHttpData-1.0 format (consumed by Cloud Storage
# Transfer Service): a "TsvHttpData-1.0" header line followed by one URL per
# line, e.g.
#
#   TsvHttpData-1.0
#   https://inaturalist-open-data.s3.amazonaws.com/photos/330330266/medium.jpg
#   https://static.inaturalist.org/photos/333790259/medium.jpeg
#
# Photos that would render a placeholder instead of the real image (unresolved
# flags, hidden by a moderator, still processing) are skipped, as are photos
# already emitted earlier in the run.
#
# SAMPLING: this walks observation_photos.id in ascending order from
# --cutoff-id and stops at --limit, so it exports a *contiguous* slice rather
# than a random sample. That is deliberate. Duplicate uploads are clustered --
# the same picture usually gets posted by the same user around the same time,
# so consecutive ids give both copies of a pair a chance to land in the export.
# A 500k random sample of a ~200M row corpus is a ~0.25% sample, and would pull
# in both halves of a duplicate pair essentially never. Use --cutoff-id to
# choose which slice: 0 starts at the oldest photos, and the max id printed at
# the end of a run feeds the next run.
#
# This whole file can be pasted into the Rails console. It only defines the
# class; command line options are parsed when it is run as a script.
#
# In the Rails console:
#
#   SinglePhotoObservationUrlExporter.export
#   SinglePhotoObservationUrlExporter.export( limit: 1000, path: "/tmp/photos.tsv", debug: true )
#
#   # or hold on to the exporter to eyeball the urls before writing anything
#   exporter = SinglePhotoObservationUrlExporter.new( cutoff_id: 500_000_000 )
#   exporter.preview
#   exporter.export
#
# From the command line:
#
#   rails runner tools/export_single_photo_observation_urls.rb
#   rails runner tools/export_single_photo_observation_urls.rb -n 500000 -c 500000000 \
#     -f ~/single_photo_observations.tsv --debug

require "set"
require "tmpdir"
require "fileutils"

class SinglePhotoObservationUrlExporter
  TSV_HEADER = "TsvHttpData-1.0"
  DEFAULT_SIZE = "medium"
  DEFAULT_LIMIT = 500_000
  DEFAULT_BATCH_ID_SPAN = 100_000

  PLUCK_COLUMNS = %w[
    observation_photos.id
    photos.id
    file_prefixes.prefix
    file_extensions.extension
  ].freeze

  # observations.observation_photos_count is an indexed counter cache, which
  # makes it a cheap and very selective prefilter, but it can drift. Confirming
  # against observation_photos itself means a stale count can never leak a
  # multi-photo observation into the export.
  SINGLE_PHOTO_SQL = <<~SQL
    NOT EXISTS (
      SELECT 1 FROM observation_photos op2
      WHERE op2.observation_id = observation_photos.observation_id
        AND op2.id != observation_photos.id
    )
  SQL

  # An unresolved flag makes Photo#sized_url return a copyright/AI placeholder.
  UNRESOLVED_FLAG_SQL = <<~SQL
    NOT EXISTS (
      SELECT 1 FROM flags f
      WHERE f.flaggable_type = 'Photo' AND f.flaggable_id = photos.id AND f.resolved = false
    )
  SQL

  attr_reader :limit, :path, :size, :cutoff_id, :open_data_only, :batch_id_span, :debug

  # Writes the manifest and returns the path it was written to.
  def self.export( **options )
    new( **options ).export
  end

  def initialize( limit: DEFAULT_LIMIT, path: nil, size: DEFAULT_SIZE, cutoff_id: 0,
    open_data_only: false, batch_id_span: DEFAULT_BATCH_ID_SPAN, debug: false )
    @limit = limit.to_i
    @size = size.to_s.downcase
    @cutoff_id = cutoff_id.to_i
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
    resume_id = cutoff_id
    limit_reached = false
    max_id = ObservationPhoto.maximum( :id ).to_i

    puts "Exporting up to #{limit} #{size} photo urls for single-photo observations " \
      "(observation_photos.id #{cutoff_id + 1}..#{max_id}, id span=#{batch_id_span}) -> #{path}"

    File.open( path, "w" ) do | file |
      file.puts TSV_HEADER

      chunk_start_id = cutoff_id + 1
      while chunk_start_id <= max_id && !limit_reached
        chunk_id_below = chunk_start_id + batch_id_span

        photo_rows( chunk_start_id, chunk_id_below ).each do | observation_photo_id, photo_id, prefix, extension |
          resume_id = observation_photo_id

          if seen_photo_ids.add?( photo_id )
            file.puts "#{prefix}/#{photo_id}/#{size}.#{extension}"
            count += 1
          end

          if count >= limit
            limit_reached = true
            break
          end
        end

        # A fully scanned window is covered through its last id, whether or not
        # any row sat there. Breaking early leaves resume_id on the last row read.
        resume_id = chunk_id_below - 1 unless limit_reached

        if debug
          puts "  observation_photos.id #{chunk_start_id}..#{chunk_id_below - 1}: " \
            "#{count} urls written (#{( Time.now - start ).round}s elapsed)"
        end
        chunk_start_id = chunk_id_below
      end
    end

    puts "Done: #{count} urls -> #{path} (#{( Time.now - start ).round}s)"
    if limit_reached
      puts "Stopped at the #{limit} url limit."
    else
      puts "Exhausted observation_photos before reaching the #{limit} url limit."
    end
    puts "Max observation_photos.id seen: #{[resume_id, max_id].min} " \
      "(use as --cutoff-id for the next slice)"
    path
  end

  # First few urls the export would emit, for sanity checking a slice from the
  # console without writing a file.
  def preview( rows = 5 )
    scope.limit( rows ).pluck( *PLUCK_COLUMNS ).map do | _op_id, photo_id, prefix, extension |
      "#{prefix}/#{photo_id}/#{size}.#{extension}"
    end
  end

  # Mirrors Observation#publicly_viewable_observation_photos in SQL, restricted
  # to observations holding exactly one photo. Building urls from plucked
  # columns rather than Photo#sized_url avoids a query per photo for
  # file_prefix, file_extension, flags and moderator_actions.
  #
  # The inner joins on file_prefixes/file_extensions drop still-processing
  # photos, since Photo#processing? is file_prefix.nil?. They also drop any
  # non-LocalPhoto rows, which is correct -- there is no url to compose without
  # a prefix.
  def scope
    relation = ObservationPhoto.
      joins( "JOIN observations o ON o.id = observation_photos.observation_id" ).
      joins( "JOIN photos ON photos.id = observation_photos.photo_id" ).
      joins( "JOIN file_prefixes ON file_prefixes.id = photos.file_prefix_id" ).
      joins( "JOIN file_extensions ON file_extensions.id = photos.file_extension_id" ).
      where( "o.observation_photos_count = 1" ).
      where( SINGLE_PHOTO_SQL ).
      # a blank prefix or extension would compose a malformed url
      where( "file_prefixes.prefix != '' AND file_extensions.extension != ''" ).
      where( UNRESOLVED_FLAG_SQL ).
      where( hidden_photo_sql ).
      # ascending id keeps the windows resumable; this rides observation_photos_pkey
      # and adds no sort to the plan
      order( "observation_photos.id" )

    return relation unless open_data_only

    relation.where( "file_prefixes.prefix LIKE ?", "%#{LocalPhoto.s3_bucket( true )}%" )
  end

  private

  # A photo whose most recent moderator action is a hide renders a placeholder
  # and gets a private S3 ACL, so the real url would 403.
  def hidden_photo_sql
    <<~SQL
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
  end

  def validate!
    raise ArgumentError, "limit must be positive" unless limit.positive?
    raise ArgumentError, "cutoff_id must not be negative" if cutoff_id.negative?
    raise ArgumentError, "batch_id_span must be positive" unless batch_id_span.positive?

    unless LocalPhoto::SIZES.map( &:to_s ).include?( size )
      raise ArgumentError, "size must be one of #{LocalPhoto::SIZES.join( ', ' )}"
    end
  end

  def default_path
    work_path = Dir.mktmpdir
    FileUtils.mkdir_p work_path, mode: 0o755
    File.join( work_path, "single_photo_observation_urls_from_#{cutoff_id}_#{size}.tsv" )
  end

  def photo_rows( chunk_start_id, chunk_id_below )
    scope.
      where( "observation_photos.id >= ?", chunk_start_id ).
      where( "observation_photos.id < ?", chunk_id_below ).
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
      Exports a TsvHttpData-1.0 download manifest of photo urls for observations
      that have exactly one photo, for perceptual hashing to find the same
      picture attached to more than one observation.

      Walks observation_photos.id ascending from --cutoff-id and stops at
      --limit, so the export is a contiguous slice rather than a random sample.
      Duplicate uploads cluster in time, so neighboring ids give both copies of
      a pair a chance to land in the same export.

      Usage:

        rails runner tools/export_single_photo_observation_urls.rb

        rails runner tools/export_single_photo_observation_urls.rb -n 500000 \\
          -c 500000000 -f ~/single_photo_observations.tsv --debug

      where [options] are:
    HELP
    opt :limit, "Maximum number of photo urls to export", type: :integer, short: "-n",
      default: SinglePhotoObservationUrlExporter::DEFAULT_LIMIT
    opt :cutoff_id, "Only export rows with observation_photos.id greater than this",
      type: :integer, short: "-c", default: 0
    opt :size, "Photo size to export", type: :string, short: "-s",
      default: SinglePhotoObservationUrlExporter::DEFAULT_SIZE
    opt :file, "Where to write output. Default will be a tmp path.", type: :string, short: "-f"
    opt :open_data_only, "Only export photos hosted in the open data bucket", type: :boolean
    opt :batch_id_span, "Number of observation_photo ids to scan per batch window",
      type: :integer, default: SinglePhotoObservationUrlExporter::DEFAULT_BATCH_ID_SPAN
    opt :debug, "Print debug statements", type: :boolean, short: "-d"
  end

  begin
    SinglePhotoObservationUrlExporter.export(
      limit: opts[:limit],
      cutoff_id: opts[:cutoff_id],
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
