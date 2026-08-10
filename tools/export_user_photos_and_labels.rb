# frozen_string_literal: true

# Exports one user's photos as two files that describe the same photo set:
#
#   1. a TsvHttpData-1.0 download manifest -- one line per DISTINCT photo, the
#      format Google Cloud Storage Transfer Service consumes
#   2. a labels CSV in the exact column format of
#      tools/export_observation_split_labels.rb -- one row per
#      observation_photos row, NOT deduped
#
# The two grains are deliberately different, and mirror the obs-split pipeline:
# you download each image once, but a photo attached to three observations
# contributes three label rows, because that multiplicity is the signal.
# Every photo_id in the CSV appears in the TSV.
#
# CSV columns, in this order:
#
#   photo_id, observation_id, user_id, photo_user_id, observed_on,
#   observation_created_at, photo_created_at, taxon_id, obs_photos_count, position
#
# WHICH PHOTOS ARE "THIS USER'S"
#
# Two different things, and the labels format exists partly to audit the gap:
# observations.user_id is the observer, photos.user_id is who owns the image.
# --scope picks which one bounds the export:
#
#   observer    (default) photos on this user's observations
#   photo_owner           photos this user owns, on whoever's observations
#   either                the union
#
# observer is the default because the obs-split experiment groups by observer.
# The summary reports the observer/owner mismatch count either way, so a run
# tells you whether the choice mattered.
#
# UNAVAILABLE PHOTOS
#
# Photos that would not download -- unresolved flag, hidden by a moderator,
# still processing -- are excluded from BOTH files so the two never disagree,
# and are counted by reason in the summary. obs_photos_count still counts every
# observation_photos row on the observation, including excluded ones, exactly as
# the obs-split spec defines it.
#
# This whole file can be pasted into the Rails console. It only defines the
# class; command line options are parsed when it is run as a script.
#
# In the Rails console:
#
#   UserPhotoExporter.export( user: "kueda" )
#   UserPhotoExporter.export( user: 383144, scope: "either", size: "large", debug: true )
#
# From the command line:
#
#   rails runner tools/export_user_photos_and_labels.rb -u kueda
#   rails runner tools/export_user_photos_and_labels.rb -u 383144 --scope either \
#     --tsv-file /tmp/photos.tsv --csv-file /tmp/labels.csv --debug

require "set"
require "csv"
require "tmpdir"
require "fileutils"

class UserPhotoExporter
  TSV_HEADER = "TsvHttpData-1.0"
  DEFAULT_SIZE = "medium"
  DEFAULT_BATCH_SIZE = 1_000
  SCOPES = %w[observer photo_owner either].freeze

  # identical to ObservationSplitLabelExporter::HEADERS, on purpose
  CSV_HEADERS = %w[
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

  # Anything past a plain "table.column" has to be wrapped in Arel.sql or
  # pluck raises ActiveRecord::UnknownAttributeReference.
  OBS_PHOTOS_COUNT_SQL = Arel.sql(
    "( SELECT COUNT(*) FROM observation_photos x " \
      "WHERE x.observation_id = observation_photos.observation_id )"
  )

  UNRESOLVED_FLAG_SQL = Arel.sql(
    "EXISTS ( SELECT 1 FROM flags f " \
      "WHERE f.flaggable_type = 'Photo' AND f.flaggable_id = photos.id AND f.resolved = false )"
  )

  HIDDEN_SQL = Arel.sql(
    "EXISTS ( SELECT 1 FROM moderator_actions ma " \
      "WHERE ma.resource_type = 'Photo' AND ma.resource_id = photos.id " \
      "AND ma.action = 'hide' AND ma.id = ( SELECT MAX( ma2.id ) FROM moderator_actions ma2 " \
      "WHERE ma2.resource_type = 'Photo' AND ma2.resource_id = photos.id ) )"
  )

  PLUCK_COLUMNS = [
    "observation_photos.photo_id",
    "observation_photos.observation_id",
    "observations.user_id",
    "photos.user_id",
    "observations.observed_on",
    "observations.created_at",
    "photos.created_at",
    "observations.taxon_id",
    OBS_PHOTOS_COUNT_SQL,
    "observation_photos.position",
    "users.deleted_at",
    "file_prefixes.prefix",
    "file_extensions.extension",
    UNRESOLVED_FLAG_SQL,
    HIDDEN_SQL
  ].freeze

  attr_reader :user, :export_scope, :size, :tsv_path, :csv_path, :batch_size, :debug, :stats

  # Writes both files and returns [tsv_path, csv_path].
  def self.export( **options )
    new( **options ).export
  end

  # user accepts a numeric id, a numeric string, or a login.
  def initialize( user:, export_scope: "observer", size: DEFAULT_SIZE, tsv_path: nil,
    csv_path: nil, batch_size: DEFAULT_BATCH_SIZE, debug: false )
    @user = find_user( user )
    @export_scope = export_scope.to_s.downcase
    @size = size.to_s.downcase
    @batch_size = batch_size.to_i
    @debug = debug
    @stats = Hash.new( 0 )
    validate!
    work_path = ( tsv_path && csv_path ) ? nil : default_work_path
    @tsv_path = tsv_path || File.join( work_path, "user_#{@user.id}_photos.tsv" )
    @csv_path = csv_path || File.join( work_path, "user_#{@user.id}_db_export.csv" )
  end

  # Writes both files and returns [tsv_path, csv_path].
  def export
    start = Time.now
    observation_ids = driving_observation_ids
    seen_photo_ids = Set.new
    contributing_observation_ids = Set.new
    photo_observation_counts = Hash.new( 0 )
    csv_rows = 0

    puts "Exporting #{size} photos for user #{user.login} (id #{user.id}, scope=#{export_scope}) " \
      "across #{observation_ids.size} observations -> #{tsv_path}, #{csv_path}"

    FileUtils.mkdir_p File.dirname( tsv_path )
    FileUtils.mkdir_p File.dirname( csv_path )

    File.open( tsv_path, "w" ) do | tsv |
      tsv.puts TSV_HEADER

      CSV.open( csv_path, "wb", encoding: "UTF-8" ) do | csv |
        csv << CSV_HEADERS

        observation_ids.each_slice( batch_size ).with_index do | chunk, index |
          rows = photo_rows( chunk ).sort_by do | row |
            [row[1].to_i, row[9].to_i, row[0].to_i]
          end

          rows.each do | row |
            next unless available?( row )

            photo_id, prefix, extension = row[0], row[11], row[12]

            # the tsv is a download list, so each image is listed once even when
            # it hangs off several observations
            if seen_photo_ids.add?( photo_id )
              tsv.puts "#{prefix}/#{photo_id}/#{size}.#{extension}"
            end
            photo_observation_counts[photo_id] += 1
            contributing_observation_ids << row[1]

            csv << csv_row( row )
            csv_rows += 1
          end

          if debug
            puts "  batch #{index + 1}/#{( observation_ids.size.to_f / batch_size ).ceil}: " \
              "#{seen_photo_ids.size} photos, #{csv_rows} label rows " \
              "(#{( Time.now - start ).round}s elapsed)"
          end
        end
      end
    end

    print_summary( observation_ids, seen_photo_ids, contributing_observation_ids,
      photo_observation_counts, csv_rows, start )
    [tsv_path, csv_path]
  end

  # Every observation the export could draw a row from. Bounding the run by
  # observation id keeps each batch on index_observation_photos_on_observation_id.
  def driving_observation_ids
    case export_scope
    when "observer"
      observer_observation_ids
    when "photo_owner"
      photo_owner_observation_ids
    else
      ( observer_observation_ids + photo_owner_observation_ids ).uniq.sort
    end
  end

  def scope
    ObservationPhoto.
      joins( "JOIN observations ON observations.id = observation_photos.observation_id" ).
      joins( "JOIN photos ON photos.id = observation_photos.photo_id" ).
      joins( "LEFT JOIN file_prefixes ON file_prefixes.id = photos.file_prefix_id" ).
      joins( "LEFT JOIN file_extensions ON file_extensions.id = photos.file_extension_id" ).
      joins( "LEFT JOIN users ON users.id = observations.user_id" ).
      where( *user_predicate )
  end

  private

  def observer_observation_ids
    Observation.where( user_id: user.id ).order( :id ).pluck( :id )
  end

  def photo_owner_observation_ids
    ObservationPhoto.
      joins( "JOIN photos ON photos.id = observation_photos.photo_id" ).
      where( "photos.user_id = ?", user.id ).
      distinct.
      order( :observation_id ).
      pluck( :observation_id )
  end

  def user_predicate
    case export_scope
    when "observer"
      ["observations.user_id = ?", user.id]
    when "photo_owner"
      ["photos.user_id = ?", user.id]
    else
      ["observations.user_id = ? OR photos.user_id = ?", user.id, user.id]
    end
  end

  # Reproduces Observation#publicly_viewable_observation_photos, but as flags on
  # the row rather than as a WHERE, so exclusions can be counted by reason.
  def available?( row )
    _photo_id, _observation_id, _user_id, _photo_user_id, _observed_on, _obs_created_at,
      _photo_created_at, _taxon_id, _obs_photos_count, _position, _user_deleted_at,
      prefix, extension, flagged, hidden = row

    if flagged
      stats[:excluded_flagged] += 1
      return false
    end
    if hidden
      stats[:excluded_hidden] += 1
      return false
    end
    # Photo#processing? is file_prefix.nil?; a blank prefix or extension would
    # compose a malformed url either way
    if prefix.to_s.empty? || extension.to_s.empty?
      stats[:excluded_unprocessed] += 1
      return false
    end

    true
  end

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

  # Dates render as YYYY-MM-DD; timestamps are forced to UTC so the files never
  # depend on the running process's zone.
  def iso8601( value )
    return nil if value.nil?
    return value.utc.iso8601 if value.respond_to?( :utc )
    return value.iso8601 if value.respond_to?( :iso8601 )

    value.to_s
  end

  def photo_rows( observation_ids )
    scope.where( observation_id: observation_ids ).pluck( *PLUCK_COLUMNS )
  end

  def find_user( identifier )
    return identifier if identifier.is_a?( User )

    key = identifier.to_s.strip
    found = if key.match?( /\A\d+\z/ )
      User.find_by( id: key.to_i ) || User.find_by( login: key )
    else
      User.find_by( login: key )
    end
    raise ArgumentError, "no User with id or login #{identifier.inspect}" if found.nil?

    found
  end

  def print_summary( observation_ids, seen_photo_ids, contributing_observation_ids,
    photo_observation_counts, csv_rows, start )
    reused = photo_observation_counts.count {| _id, count | count >= 2 }
    excluded = stats[:excluded_flagged] + stats[:excluded_hidden] + stats[:excluded_unprocessed]

    puts "Done in #{( Time.now - start ).round}s"
    puts "  tsv (one line per distinct photo): #{seen_photo_ids.size} -> #{tsv_path}"
    puts "  csv (one row per observation photo): #{csv_rows} -> #{csv_path}"
    puts "  observations scanned:              #{observation_ids.size}"
    puts "  observations contributing rows:    #{contributing_observation_ids.size}"
    puts "  photos in >= 2 observations:       #{reused}"
    puts "  photos excluded (in neither file): #{excluded}"
    if excluded.positive?
      puts "    unresolved flag: #{stats[:excluded_flagged]}"
      puts "    hidden by a moderator: #{stats[:excluded_hidden]}"
      puts "    still processing / no url: #{stats[:excluded_unprocessed]}"
    end
    puts "  rows where photo owner != observer: #{stats[:observer_photo_owner_mismatch]}" \
      "#{scope_hint}"
    if stats[:rows_with_deleted_user].positive?
      puts "  rows whose observer is a soft-deleted user: #{stats[:rows_with_deleted_user]}"
    end
    return unless csv_rows.positive?

    puts "  mean label rows per photo: #{( csv_rows.to_f / seen_photo_ids.size ).round( 4 )}"
  end

  def scope_hint
    return "" unless stats[:observer_photo_owner_mismatch].positive?
    return " (--scope either would widen the export)" if export_scope == "observer"

    ""
  end

  def validate!
    raise ArgumentError, "batch_size must be positive" unless batch_size.positive?

    unless SCOPES.include?( export_scope )
      raise ArgumentError, "scope must be one of #{SCOPES.join( ', ' )}"
    end

    return if LocalPhoto::SIZES.map( &:to_s ).include?( size )

    raise ArgumentError, "size must be one of #{LocalPhoto::SIZES.join( ', ' )}"
  end

  def default_work_path
    work_path = Dir.mktmpdir
    FileUtils.mkdir_p work_path, mode: 0o755
    work_path
  end
end

# Only when run as a script. `rails runner` sets $0 to the file path and
# Kernel.loads it, so this is false when the file is pasted into the console.
if __FILE__ == $PROGRAM_NAME
  require "rubygems"
  require "optimist"

  opts = Optimist.options do
    banner <<~HELP
      Exports one user's photos as two files describing the same photo set: a
      TsvHttpData-1.0 download manifest (one line per distinct photo) and a labels
      CSV in the column format of tools/export_observation_split_labels.rb (one
      row per observation_photos row, not deduped).

      Usage:

        rails runner tools/export_user_photos_and_labels.rb -u kueda

        rails runner tools/export_user_photos_and_labels.rb -u 383144 --scope either \\
          --tsv-file /tmp/photos.tsv --csv-file /tmp/labels.csv --debug

      where [options] are:
    HELP
    opt :user, "User id or login to export photos for", type: :string, short: "-u", required: true
    opt :scope, "Which photos count as this user's: observer, photo_owner, either",
      type: :string, default: "observer"
    opt :size, "Photo size for the tsv urls", type: :string, short: "-s",
      default: UserPhotoExporter::DEFAULT_SIZE
    opt :tsv_file, "Where to write the TsvHttpData manifest. Default is a tmp path.",
      type: :string
    opt :csv_file, "Where to write the labels csv. Default is a tmp path.", type: :string
    opt :batch_size, "Observations per query", type: :integer,
      default: UserPhotoExporter::DEFAULT_BATCH_SIZE
    opt :debug, "Print debug statements", type: :boolean, short: "-d"
  end

  begin
    UserPhotoExporter.export(
      user: opts[:user],
      export_scope: opts[:scope],
      size: opts[:size],
      tsv_path: opts[:tsv_file],
      csv_path: opts[:csv_file],
      batch_size: opts[:batch_size],
      debug: opts[:debug]
    )
  rescue ArgumentError => e
    Optimist.die e.message
  end
end
