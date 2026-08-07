# frozen_string_literal: true

# Exports labels.csv for the pollination classifier: every observation carrying
# one of the labelling observation fields, joined to every photo on it.
#
# Columns:
#
#   observation_id  int64   iNat observation id
#   photo_id        int64   iNat photo id
#   photo_url       string  url the image can be fetched from
#   label           string  exactly "pollination" or "not_pollination"
#   label_int       int8    1 = pollination, 0 = not_pollination
#   taxon_id        int64   nullable; analysis / stratification only, NOT a feature
#   source          string  which field and value produced the label, for auditing
#
# ROW GRAIN
#
# One row per (observation_id, photo_id). Observations with several photos
# contribute several rows, all carrying the same label -- the label belongs to
# the observation, not to the individual photo. So observation_id is NOT unique
# in this file; the pair is. Group by observation_id before splitting into
# train/test, or the same observation lands on both sides.
#
# Observations with no exportable photo produce no rows and are counted in the
# summary.
#
# WHERE THE LABELS COME FROM
#
# There is no pollination annotation -- nothing in controlled_terms mentions
# pollination, so annotations play no part here. The labels come from
# observation field 17991 "Pollination interaction", whose allowed values are
# exactly "Yes" and "No". That field supplies BOTH classes on its own; negatives
# are observations a human explicitly marked "No", not unlabeled observations
# assumed negative.
#
# Other pollination-ish fields are deliberately NOT included by default, because
# their "No" does not mean "not pollination":
#
#   13217 Buzz-pollination    Yes/No/Not Heard    -- "No" = not buzzing, may still pollinate
#   11177 Pollinator Predator Yes/No/Not Observed -- about predation, not pollination
#
# Add them only with a value mapping you have thought through.
#
# Values outside the positive/negative lists ("Not Heard", "Unknown", free text)
# are counted and skipped rather than guessed at.
#
# An observation can carry several of the requested fields, so labels are
# collapsed per observation: any positive value wins over a negative one, and
# disagreements are counted and reported.
#
# Photos that would render a placeholder instead of the real image (unresolved
# flags, hidden by a moderator, still processing) are skipped.
#
# This whole file can be pasted into the Rails console. It only defines the
# class; command line options are parsed when it is run as a script.
#
# In the Rails console:
#
#   PollinationLabelExporter.export
#   PollinationLabelExporter.export( size: "large", debug: true )
#
#   # an explicit mapping, when one list of positive values will not do
#   PollinationLabelExporter.export(
#     label_map: {
#       17991 => { "Yes" => "pollination", "No" => "not_pollination" },
#       9813 => { "Pollinating" => "pollination", "Robbing nectar" => "not_pollination" }
#     }
#   )
#
# From the command line:
#
#   rails runner tools/export_pollination_labels.rb
#   rails runner tools/export_pollination_labels.rb -o 17991 -s medium --debug

require "set"
require "csv"
require "tmpdir"
require "fileutils"

class PollinationLabelExporter
  POSITIVE_LABEL = "pollination"
  NEGATIVE_LABEL = "not_pollination"

  HEADERS = %w[
    observation_id
    photo_id
    photo_url
    label
    label_int
    taxon_id
    source
  ].freeze

  PLUCK_COLUMNS = %w[
    observation_field_values.observation_id
    observation_field_values.observation_field_id
    observation_field_values.value
    observations.taxon_id
    photos.id
    file_prefixes.prefix
    file_extensions.extension
  ].freeze

  # 17991 "Pollination interaction" is the only field whose Yes/No maps cleanly
  # onto the two classes. See the note at the top of this file.
  DEFAULT_OBSERVATION_FIELD_IDS = [17991].freeze
  DEFAULT_POSITIVE_VALUES = ["Yes"].freeze
  DEFAULT_NEGATIVE_VALUES = ["No"].freeze

  DEFAULT_SIZE = "medium"
  DEFAULT_BATCH_ID_SPAN = 100_000

  UNRESOLVED_FLAG_SQL = <<~SQL
    NOT EXISTS (
      SELECT 1 FROM flags f
      WHERE f.flaggable_type = 'Photo' AND f.flaggable_id = photos.id AND f.resolved = false
    )
  SQL

  attr_reader :label_map, :observation_field_ids, :path, :size, :batch_id_span, :debug, :stats

  # Writes labels.csv and returns the path it was written to.
  def self.export( **options )
    new( **options ).export
  end

  def initialize( label_map: nil, observation_field_ids: DEFAULT_OBSERVATION_FIELD_IDS,
    positive_values: DEFAULT_POSITIVE_VALUES, negative_values: DEFAULT_NEGATIVE_VALUES,
    path: nil, size: DEFAULT_SIZE, batch_id_span: DEFAULT_BATCH_ID_SPAN, debug: false )
    @size = size.to_s.downcase
    @batch_id_span = batch_id_span.to_i
    @debug = debug
    @label_map = label_map ? normalize_label_map( label_map ) : build_label_map(
      normalize_field_ids( observation_field_ids ), positive_values, negative_values
    )
    @observation_field_ids = @label_map.keys
    @stats = Hash.new( 0 )
    validate!
    @path = path || default_path
  end

  # Writes labels.csv and returns the path it was written to.
  def export
    start = Time.now
    observations = collect_observations( start )

    rows = 0
    positives = 0

    FileUtils.mkdir_p File.dirname( path )
    CSV.open( path, "wb", encoding: "UTF-8" ) do | csv |
      csv << HEADERS

      observations.keys.sort.each do | observation_id |
        observation = observations[observation_id]
        positive = observation[:label] == POSITIVE_LABEL
        source = observation[:sources].sort.join( ";" )

        observation[:photos].keys.sort.each do | photo_id |
          prefix, extension = observation[:photos][photo_id]

          csv << [
            observation_id,
            photo_id,
            "#{prefix}/#{photo_id}/#{size}.#{extension}",
            observation[:label],
            positive ? 1 : 0,
            observation[:taxon_id],
            source
          ]

          rows += 1
          positives += 1 if positive
        end
      end
    end

    print_summary( rows, positives, observations, start )
    path
  end

  # Mirrors Observation#publicly_viewable_observation_photos in SQL. An
  # unresolved flag or a HIDE moderator action makes Photo#sized_url return a
  # placeholder image (and hidden photos get a private S3 ACL, so the real url
  # 403s). The inner joins on file_prefixes/file_extensions drop still-processing
  # photos, since Photo#processing? is file_prefix.nil?.
  def scope
    field_value_scope.
      joins( "JOIN observations ON observations.id = observation_field_values.observation_id" ).
      joins( "JOIN observation_photos ON observation_photos.observation_id = observation_field_values.observation_id" ).
      joins( "JOIN photos ON photos.id = observation_photos.photo_id" ).
      joins( "JOIN file_prefixes ON file_prefixes.id = photos.file_prefix_id" ).
      joins( "JOIN file_extensions ON file_extensions.id = photos.file_extension_id" ).
      # a blank prefix or extension would compose a malformed url
      where( "file_prefixes.prefix != '' AND file_extensions.extension != ''" ).
      where( UNRESOLVED_FLAG_SQL ).
      where( hidden_photo_sql )
  end

  # Every observation carrying one of the requested fields, whether or not any
  # of its photos survive the filters above.
  def observation_count
    field_value_scope.distinct.count( :observation_id )
  end

  private

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

  # Walks the field values in indexed id windows and folds them into one entry
  # per observation, each holding every photo on that observation. Collapsing has
  # to happen across the whole run, not per window, since an observation's field
  # values can straddle a window boundary.
  def collect_observations( start )
    observations = {}
    min_id, max_id = id_bounds
    # every observation reachable through the photo join, mapped value or not.
    # An observation with no exportable photo never appears in these rows at
    # all, which is what separates the two reasons for a missing observation.
    @photo_observation_ids = Set.new

    puts "Exporting pollination labels for observation fields #{observation_field_ids.join( ', ' )} " \
      "(observation_field_values.id #{min_id}..#{max_id}, id span=#{batch_id_span}) -> #{path}"

    chunk_start_id = min_id
    while chunk_start_id <= max_id
      chunk_id_below = chunk_start_id + batch_id_span

      photo_rows( chunk_start_id, chunk_id_below ).each do | observation_id, field_id, value, taxon_id,
        photo_id, prefix, extension |
        @photo_observation_ids << observation_id

        label = label_for( field_id, value )
        if label.nil?
          stats[:unmapped_values] += 1
          next
        end

        observation = observations[observation_id] ||= {
          photos: {},
          taxon_id: taxon_id,
          label: label,
          sources: []
        }

        # the same photo comes back once per matching field value on the observation
        observation[:photos][photo_id] = [prefix, extension]

        source = "observation_field:#{field_id}=#{value}"
        observation[:sources] << source unless observation[:sources].include?( source )

        next if observation[:label] == label

        # a positive from any field outranks a negative from another
        stats[:conflicting_observations] += 1
        observation[:label] = POSITIVE_LABEL
      end

      if debug
        puts "  observation_field_values.id #{chunk_start_id}..#{chunk_id_below - 1}: " \
          "#{observations.size} observations (#{( Time.now - start ).round}s elapsed)"
      end
      chunk_start_id = chunk_id_below
    end

    observations
  end

  def print_summary( rows, positives, observations, start )
    labelled = observations.size
    positive_observations = observations.count {| _id, o | o[:label] == POSITIVE_LABEL }
    with_photos = @photo_observation_ids.size
    total_observations = observation_count

    puts "Done: #{rows} rows -> #{path} (#{( Time.now - start ).round}s)"
    puts "  rows (one per observation photo): #{rows}"
    puts "    positives (#{POSITIVE_LABEL}):     #{positives}"
    puts "    negatives (#{NEGATIVE_LABEL}): #{rows - positives}"
    puts "  observations exported:            #{labelled} " \
      "(#{positive_observations} #{POSITIVE_LABEL}, #{labelled - positive_observations} #{NEGATIVE_LABEL})"
    puts "  observations in the field(s):     #{total_observations}"
    puts "    dropped, no exportable photo:   #{total_observations - with_photos}"
    puts "    dropped, no value in the label map: #{with_photos - labelled}"
    puts "  field values skipped as unmapped: #{stats[:unmapped_values]}"
    puts "  observations with disagreeing fields (resolved as #{POSITIVE_LABEL}): " \
      "#{stats[:conflicting_observations]}"
    return unless rows.positive?

    puts "  positive rate: #{( 100.0 * positives / rows ).round( 2 )}% of rows, " \
      "#{( 100.0 * positive_observations / labelled ).round( 2 )}% of observations"
  end

  def label_for( field_id, value )
    label_map[field_id]&.[]( value.to_s.strip.downcase )
  end

  def normalize_field_ids( ids )
    Array( ids ).
      flat_map {| id | id.to_s.split( "," ) }.
      map {| id | id.strip.to_i }.
      uniq.
      reject( &:zero? )
  end

  def build_label_map( field_ids, positive_values, negative_values )
    values = {}
    Array( positive_values ).flat_map {| v | v.to_s.split( "," ) }.each do | value |
      values[value.strip.downcase] = POSITIVE_LABEL
    end
    Array( negative_values ).flat_map {| v | v.to_s.split( "," ) }.each do | value |
      values[value.strip.downcase] = NEGATIVE_LABEL
    end
    field_ids.to_h {| field_id | [field_id, values] }
  end

  def normalize_label_map( map )
    map.to_h do | field_id, values |
      [
        field_id.to_i,
        values.to_h {| value, label | [value.to_s.strip.downcase, label.to_s] }
      ]
    end
  end

  def validate!
    raise ArgumentError, "batch_id_span must be positive" unless batch_id_span.positive?

    if label_map.empty? || label_map.values.any?( &:empty? )
      raise ArgumentError, "every observation field needs at least one mapped value"
    end

    bad_labels = label_map.values.flat_map( &:values ).uniq - [POSITIVE_LABEL, NEGATIVE_LABEL]
    unless bad_labels.empty?
      raise ArgumentError, "labels must be #{POSITIVE_LABEL} or #{NEGATIVE_LABEL}, got #{bad_labels.join( ', ' )}"
    end

    unless LocalPhoto::SIZES.map( &:to_s ).include?( size )
      raise ArgumentError, "size must be one of #{LocalPhoto::SIZES.join( ', ' )}"
    end

    missing = observation_field_ids - ObservationField.where( id: observation_field_ids ).pluck( :id )
    return if missing.empty?

    raise ArgumentError, "no ObservationField with id #{missing.join( ', ' )}"
  end

  def default_path
    work_path = Dir.mktmpdir
    FileUtils.mkdir_p work_path, mode: 0o755
    File.join( work_path, "labels.csv" )
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
      Exports labels.csv for the pollination classifier: every observation
      carrying one of the labelling observation fields, joined to every photo on
      it, with the label and the url the image can be fetched from.

      One row per (observation_id, photo_id), so observation_id repeats for
      multi-photo observations. Group by observation_id before splitting into
      train/test.

      Labels come from observation field 17991 "Pollination interaction", whose
      allowed values are exactly Yes and No, so negatives are explicitly marked
      "No" rather than unlabeled observations assumed negative. Other
      pollination-ish fields are not included by default because their "No" means
      something else (see the notes at the top of this file).

      Usage:

        rails runner tools/export_pollination_labels.rb

        rails runner tools/export_pollination_labels.rb -o 17991 -s medium \\
          -f ~/labels.csv --debug

      where [options] are:
    HELP
    opt :observation_field_ids, "Comma-separated ObservationField ids supplying labels",
      type: :string, short: "-o",
      default: PollinationLabelExporter::DEFAULT_OBSERVATION_FIELD_IDS.join( "," )
    opt :positive_values, "Comma-separated field values meaning pollination",
      type: :string, default: PollinationLabelExporter::DEFAULT_POSITIVE_VALUES.join( "," )
    opt :negative_values, "Comma-separated field values meaning not_pollination",
      type: :string, default: PollinationLabelExporter::DEFAULT_NEGATIVE_VALUES.join( "," )
    opt :size, "Photo size to build urls for", type: :string, short: "-s",
      default: PollinationLabelExporter::DEFAULT_SIZE
    opt :file, "Where to write labels.csv. Default will be a tmp path.", type: :string, short: "-f"
    opt :batch_id_span, "Number of observation_field_value ids to scan per batch window",
      type: :integer, default: PollinationLabelExporter::DEFAULT_BATCH_ID_SPAN
    opt :debug, "Print debug statements", type: :boolean, short: "-d"
  end

  begin
    PollinationLabelExporter.export(
      observation_field_ids: opts[:observation_field_ids],
      positive_values: opts[:positive_values],
      negative_values: opts[:negative_values],
      size: opts[:size],
      path: opts[:file],
      batch_id_span: opts[:batch_id_span],
      debug: opts[:debug]
    )
  rescue ArgumentError => e
    Optimist.die e.message
  end
end
