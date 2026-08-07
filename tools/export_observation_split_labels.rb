# frozen_string_literal: true

# Exports the observation-splitting labels: one CSV row per observation_photos
# row for every photo id in the manifest.
#
# Photo ids are NOT deduped. A photo attached to three observations produces
# three rows -- that multiplicity is the signal the experiment is looking for.
#
# Columns, in this order:
#
#   photo_id                observation_photos.photo_id
#   observation_id          observation_photos.observation_id
#   user_id                 observations.user_id -- the observer, the grouping key
#   photo_user_id           photos.user_id -- audit only, catches observer/owner mismatch
#   observed_on             observations.observed_on, nullable, ISO 8601 date
#   observation_created_at  observations.created_at, ISO 8601 UTC
#   photo_created_at        photos.created_at, ISO 8601 UTC
#   taxon_id                observations.taxon_id, nullable, analysis only
#   obs_photos_count        observation_photos on that observation, manifest or not
#   position                observation_photos.position, nullable
#
# SOFT DELETES
#
# The spec asks to exclude soft-deleted photos and observations "if the schema
# tracks that". It does not: neither photos nor observations has a deleted_at
# column. Deletion is a hard DELETE with an audit row written to deleted_photos
# or deleted_observations. So deleted records simply do not join, and their
# manifest ids land in the "zero rows" count instead -- no filter needed.
#
# The one deleted_at in this neighbourhood is on users. Content belonging to a
# soft-deleted user is pending deletion but still present, so it is counted and
# reported, and --exclude-deleted-user-content will drop it if you want that.
# It is off by default because the spec scopes the exclusion to photos and
# observations, not users.
#
# MANIFEST AND UPLOAD
#
# Both are local file operations: this container has no gcloud/gsutil and no
# GCS credentials. Download the manifest and upload the result yourself --
# the exact gsutil command to run is printed at the end.
#
#   gsutil cp gs://interactions-training/experiments/data/obs-split/v1/manifest.csv /tmp/manifest.csv
#
# The manifest is read as CSV with a photo_id column (a gcs_uri column is
# ignored); a headerless single-column list also works.
#
# This whole file can be pasted into the Rails console. It only defines the
# class; command line options are parsed when it is run as a script.
#
# In the Rails console:
#
#   ObservationSplitLabelExporter.export( manifest: "/tmp/manifest.csv" )
#   ObservationSplitLabelExporter.export( manifest: "/tmp/manifest.csv", debug: true )
#
# From the command line:
#
#   rails runner tools/export_observation_split_labels.rb -m /tmp/manifest.csv
#   rails runner tools/export_observation_split_labels.rb -m /tmp/manifest.csv \
#     -f /tmp/db_export.csv --missing-file /tmp/missing_photo_ids.txt --debug

require "set"
require "csv"
require "tmpdir"
require "fileutils"

class ObservationSplitLabelExporter
  DEFAULT_BATCH_SIZE = 5_000
  GCS_DESTINATION = "gs://interactions-training/experiments/data/obs-split/v1/db_export.csv"

  HEADERS = %w[
    photo_id
    observation_id
    user_id
    photo_user_id
    observed_on
    observation_created_at
    photo_created_at
    taxon_id
    obs_photos_count
    position
  ].freeze

  # obs_photos_count is counted off observation_photos rather than read from the
  # observations.observation_photos_count counter cache: the cache can drift, and
  # this is an index-only scan on (observation_id).
  #
  # The subquery has to be wrapped in Arel.sql -- plain "table.column" strings
  # pass Rails' raw SQL allowlist, but anything more raises
  # ActiveRecord::UnknownAttributeReference.
  PLUCK_COLUMNS = [
    "observation_photos.photo_id",
    "observation_photos.observation_id",
    "observations.user_id",
    "photos.user_id",
    "observations.observed_on",
    "observations.created_at",
    "photos.created_at",
    "observations.taxon_id",
    Arel.sql(
      "( SELECT COUNT(*) FROM observation_photos x " \
        "WHERE x.observation_id = observation_photos.observation_id )"
    ),
    "observation_photos.position",
    "users.deleted_at"
  ].freeze

  attr_reader :manifest_path, :path, :missing_path, :batch_size, :exclude_deleted_user_content,
    :debug, :stats

  # Writes the export and returns the path it was written to.
  def self.export( **options )
    new( **options ).export
  end

  def initialize( manifest:, path: nil, missing_path: nil, batch_size: DEFAULT_BATCH_SIZE,
    exclude_deleted_user_content: false, debug: false )
    @manifest_path = File.expand_path( manifest.to_s )
    @missing_path = missing_path && File.expand_path( missing_path )
    @batch_size = batch_size.to_i
    @exclude_deleted_user_content = exclude_deleted_user_content
    @debug = debug
    @stats = Hash.new( 0 )
    validate!
    @path = path || default_path
  end

  # Writes the export and returns the path it was written to.
  def export
    start = Time.now
    manifest_photo_ids = load_manifest
    seen_photo_ids = Set.new
    rows = 0
    reused_photo_ids = 0

    puts "Exporting observation photo rows for #{manifest_photo_ids.size} manifest photo ids " \
      "(batch size=#{batch_size}) -> #{path}"

    FileUtils.mkdir_p File.dirname( path )
    CSV.open( path, "wb", encoding: "UTF-8" ) do | csv |
      csv << HEADERS

      manifest_photo_ids.each_slice( batch_size ).with_index do | chunk, index |
        # every row for a given photo id is inside this chunk, since chunks are
        # cut on photo id, so photo-level stats can be settled here
        by_photo_id = photo_rows( chunk ).group_by( &:first )

        chunk.each do | photo_id |
          photo_rows_for_id = by_photo_id[photo_id]
          next if photo_rows_for_id.nil? || photo_rows_for_id.empty?

          seen_photo_ids << photo_id
          observation_ids = photo_rows_for_id.map {| row | row[1] }.uniq
          reused_photo_ids += 1 if observation_ids.size >= 2

          photo_rows_for_id.sort_by {| row | [row[1].to_i, row[9].to_i] }.each do | row |
            csv << csv_row( row )
            rows += 1
          end
        end

        if debug
          puts "  batch #{index + 1}/#{( manifest_photo_ids.size.to_f / batch_size ).ceil}: " \
            "#{rows} rows, #{seen_photo_ids.size} photo ids matched " \
            "(#{( Time.now - start ).round}s elapsed)"
        end
      end
    end

    missing_photo_ids = manifest_photo_ids.reject {| id | seen_photo_ids.include?( id ) }
    write_missing( missing_photo_ids )
    print_summary( manifest_photo_ids, seen_photo_ids, rows, reused_photo_ids,
      missing_photo_ids, start )
    path
  end

  def scope
    relation = ObservationPhoto.
      joins( "JOIN observations ON observations.id = observation_photos.observation_id" ).
      joins( "JOIN photos ON photos.id = observation_photos.photo_id" ).
      joins( "LEFT JOIN users ON users.id = observations.user_id" )

    return relation unless exclude_deleted_user_content

    relation.where( "users.deleted_at IS NULL" )
  end

  private

  def csv_row( row )
    photo_id, observation_id, user_id, photo_user_id, observed_on, observation_created_at,
      photo_created_at, taxon_id, obs_photos_count, position, user_deleted_at = row

    stats[:rows_with_deleted_user] += 1 unless user_deleted_at.nil?
    if !photo_user_id.nil? && photo_user_id != user_id
      stats[:observer_photo_owner_mismatch] += 1
    end

    [
      photo_id,
      observation_id,
      user_id,
      photo_user_id,
      iso8601( observed_on ),
      iso8601( observation_created_at ),
      iso8601( photo_created_at ),
      taxon_id,
      obs_photos_count,
      position
    ]
  end

  # Dates render as YYYY-MM-DD; timestamps are forced to UTC so the file never
  # depends on the running process's zone.
  def iso8601( value )
    return nil if value.nil?
    return value.utc.iso8601 if value.respond_to?( :utc )
    return value.iso8601 if value.respond_to?( :iso8601 )

    value.to_s
  end

  def photo_rows( photo_ids )
    scope.where( photo_id: photo_ids ).pluck( *PLUCK_COLUMNS )
  end

  # Sorted and deduped, so the export is deterministic and every photo id lands
  # in exactly one batch.
  def load_manifest
    photo_ids = []
    malformed = 0

    first_line = File.open( manifest_path ) {| f | f.gets.to_s }
    headers = first_line.downcase.include?( "photo_id" )

    CSV.foreach( manifest_path, headers: headers ) do | row |
      raw = headers ? row["photo_id"] : row[0]
      id = raw.to_s.strip.to_i
      if id.zero?
        malformed += 1
        next
      end

      photo_ids << id
    end

    stats[:manifest_malformed_rows] = malformed
    stats[:manifest_duplicate_ids] = photo_ids.size - photo_ids.uniq.size
    photo_ids.uniq.sort
  end

  def write_missing( missing_photo_ids )
    return if missing_path.nil?

    FileUtils.mkdir_p File.dirname( missing_path )
    File.open( missing_path, "w" ) do | file |
      missing_photo_ids.each {| id | file.puts id }
    end
    puts "Wrote #{missing_photo_ids.size} unmatched manifest photo ids -> #{missing_path}"
  end

  def print_summary( manifest_photo_ids, seen_photo_ids, rows, reused_photo_ids,
    missing_photo_ids, start )
    puts "Done: #{rows} rows -> #{path} (#{( Time.now - start ).round}s)"
    puts "  1. total rows:                                   #{rows}"
    puts "  2. distinct photo_ids:                           #{seen_photo_ids.size}"
    puts "  3. manifest photo_ids with zero rows:            #{missing_photo_ids.size}"
    puts "  4. photo_ids in >= 2 observations:               #{reused_photo_ids}"
    puts "  manifest photo_ids read:                         #{manifest_photo_ids.size}"
    if stats[:manifest_duplicate_ids].positive?
      puts "    duplicate ids in manifest (collapsed):         #{stats[:manifest_duplicate_ids]}"
    end
    if stats[:manifest_malformed_rows].positive?
      puts "    malformed manifest rows (skipped):             #{stats[:manifest_malformed_rows]}"
    end
    puts "  rows whose observer is a soft-deleted user:      #{stats[:rows_with_deleted_user]}" \
      "#{exclude_deleted_user_content ? ' (excluded)' : ' (included; --exclude-deleted-user-content to drop)'}"
    puts "  rows where photo owner != observer:              #{stats[:observer_photo_owner_mismatch]}"
    if rows.positive?
      puts "  mean rows per matched photo_id: " \
        "#{( rows.to_f / seen_photo_ids.size ).round( 4 )}"
    end
    puts
    puts "Upload with:"
    puts "  gsutil cp #{path} #{GCS_DESTINATION}"
  end

  def validate!
    raise ArgumentError, "batch_size must be positive" unless batch_size.positive?
    raise ArgumentError, "no manifest at #{manifest_path}" unless File.exist?( manifest_path )
  end

  def default_path
    work_path = Dir.mktmpdir
    FileUtils.mkdir_p work_path, mode: 0o755
    File.join( work_path, "db_export.csv" )
  end
end

# Only when run as a script. `rails runner` sets $0 to the file path and
# Kernel.loads it, so this is false when the file is pasted into the console.
if __FILE__ == $PROGRAM_NAME
  require "rubygems"
  require "optimist"

  opts = Optimist.options do
    banner <<~HELP
      Exports the observation-splitting labels: one row per observation_photos row
      for every photo id in the manifest. Photo ids are not deduped -- a photo on
      three observations yields three rows.

      The manifest is read from a local path and the result is written locally;
      this environment has no gcloud/gsutil. Fetch and upload yourself:

        gsutil cp gs://interactions-training/experiments/data/obs-split/v1/manifest.csv /tmp/manifest.csv
        rails runner tools/export_observation_split_labels.rb -m /tmp/manifest.csv -f /tmp/db_export.csv
        gsutil cp /tmp/db_export.csv gs://interactions-training/experiments/data/obs-split/v1/db_export.csv

      where [options] are:
    HELP
    opt :manifest, "Local path to manifest.csv (photo_id column)", type: :string,
      short: "-m", required: true
    opt :file, "Where to write db_export.csv. Default will be a tmp path.",
      type: :string, short: "-f"
    opt :missing_file, "Also write manifest photo ids that matched no rows here",
      type: :string
    opt :batch_size, "Photo ids per query", type: :integer,
      default: ObservationSplitLabelExporter::DEFAULT_BATCH_SIZE
    opt :exclude_deleted_user_content,
      "Drop rows whose observer is a soft-deleted user (off by default)", type: :boolean
    opt :debug, "Print debug statements", type: :boolean, short: "-d"
  end

  begin
    ObservationSplitLabelExporter.export(
      manifest: opts[:manifest],
      path: opts[:file],
      missing_path: opts[:missing_file],
      batch_size: opts[:batch_size],
      exclude_deleted_user_content: opts[:exclude_deleted_user_content],
      debug: opts[:debug]
    )
  rescue ArgumentError => e
    Optimist.die e.message
  end
end
