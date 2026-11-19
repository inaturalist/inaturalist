# frozen_string_literal: true

require "csv"
require "exemplar_identification_scoring_run"

# One-time fill of exemplar_identification_scores for the exemplar
# identifications created before the scores existed. Imports the results of
# the initial run (July 2026) from exemplar_identification_backfill.csv,
# gives every other exemplar a row, then fixes what the hooks missed while it
# ran. Rows are inserted, never overwritten, so a row written by a hook wins.
# The July lines not imported as they are, and the rows reset afterwards, are
# listed in exemplar_identification_backfill_rejects.csv next to the file.
# Rows are read and written in batches, and the file is streamed.
class ExemplarIdentificationScoreBackfill
  BATCH_SIZE = 1000
  REJECTS_FILE = "exemplar_identification_backfill_rejects.csv"

  REJECT_DETAILS = {
    changed: "body changed since the initial run",
    incomplete: "incomplete result",
    existing: "row already there: created by the site, or by an earlier attempt"
  }.freeze
  RESET_EDITED_DETAIL = "body edited during the backfill"

  # Statuses of the file kept as they are when the body hasn't changed
  RESULT_STATUSES = ExemplarIdentificationScoringRun::RESULT_STATUSES + [
    ExemplarIdentificationScore::SKIPPED_SHORT,
    ExemplarIdentificationScore::SKIPPED_DUPLICATE
  ].freeze

  attr_reader :started_at

  # started_at is when the backfill first started, to rerun it after a crash
  def initialize( path, started_at: Time.now )
    @path = path
    @started_at = started_at
  end

  def rejects_path
    File.join( File.dirname( @path ), REJECTS_FILE )
  end

  def import
    counts = Hash.new( 0 )
    CSV.foreach( @path, headers: true, encoding: "UTF-8" ).each_slice( BATCH_SIZE ) do | lines |
      write_rejects( import_lines( lines, counts ) )
    end
    counts
  end

  def fill_gaps
    inserted = 0
    ExemplarIdentification.in_batches( of: BATCH_SIZE ) do | batch |
      now = Time.now
      rows = batch.pluck( :id, :active ).map do | id, active |
        unscored_attributes( active ).merge(
          "exemplar_identification_id" => id,
          "created_at" => now,
          "updated_at" => now
        )
      end
      inserted += insert( rows ).size
    end
    inserted
  end

  # Bodies edited while the import's batch holding their row was still
  # uncommitted: the body hook found no row to reset. Only the
  # identifications updated since the start are compared with the file
  def reset_edited
    bodies = ExemplarIdentificationScore.
      joins( exemplar_identification: :identification ).
      where( "identifications.updated_at >= ?", @started_at ).
      pluck( "identifications.id", "identifications.body" ).
      to_h
    return 0 if bodies.empty?

    edited_ids = []
    CSV.foreach( @path, headers: true, encoding: "UTF-8" ) do | line |
      id = line["id"].to_i
      edited_ids << id if bodies.key?( id ) && sanitize_text( bodies[id] ) != line["body"]
    end
    reset( edited_ids.uniq )
  end

  # active changes made while the batch holding their row was still
  # uncommitted: the active hook found no row to update
  def reconcile_active
    each_batch do | batch |
      batch.
        where( status: ExemplarIdentificationScore::ON_HOLD ).
        joins( :exemplar_identification ).
        where( exemplar_identifications: { active: true } ).
        update_all( status: ExemplarIdentificationScore::PENDING ) +
        batch.
          where( status: ExemplarIdentificationScore::PENDING ).
          joins( :exemplar_identification ).
          where( exemplar_identifications: { active: false } ).
          update_all( status: ExemplarIdentificationScore::ON_HOLD )
    end
  end

  # Rows whose exemplar, or its identification, no longer exists: destroyed
  # while the batch holding their row was still uncommitted, or deleted
  # without callbacks
  def delete_orphans
    each_batch do | batch |
      batch.where( <<~SQL ).delete_all
        NOT EXISTS (
          SELECT 1
          FROM exemplar_identifications
          JOIN identifications ON identifications.id = exemplar_identifications.identification_id
          WHERE exemplar_identifications.id = exemplar_identification_scores.exemplar_identification_id
        )
      SQL
    end
  end

  def status_counts
    ExemplarIdentificationScore.group( :status ).count
  end

  # Every exemplar should have exactly one row
  def row_check
    exemplars = ExemplarIdentification.count
    rows = ExemplarIdentificationScore.count
    { exemplars: exemplars, rows: rows, difference: exemplars - rows }
  end

  private

  # Inserts the rows of the lines, and returns the lines not imported as they
  # are
  def import_lines( lines, counts )
    exemplars = ExemplarIdentification.
      joins( :identification ).
      where( identification_id: lines.map {| line | line["id"].to_i } ).
      pluck( :identification_id, :id, :active, "identifications.body" ).
      index_by( &:first )
    now = Time.now
    rejects = []
    imports = lines.filter_map do | line |
      _, exemplar_id, active, body = exemplars[line["id"].to_i]
      unless exemplar_id
        counts[:no_exemplar] += 1
        rejects << [line["id"], :no_exemplar, "exemplar identification deleted since the initial run"]
        next
      end

      outcome, attributes = july_attributes( line, active, body )
      row = attributes.merge( "exemplar_identification_id" => exemplar_id, "created_at" => now, "updated_at" => now )
      [line, outcome, row]
    end
    inserted = insert( imports.map( &:last ) ).to_set
    imports.each do | line, outcome, row |
      outcome = :existing unless inserted.include?( row["exemplar_identification_id"] )
      counts[outcome] += 1
      detail = REJECT_DETAILS[outcome]
      detail = line["error"] if outcome == :incomplete
      rejects << [line["id"], outcome, detail] if detail
    end
    rejects
  end

  def july_attributes( line, active, body )
    status = line["status"]
    if sanitize_text( body ) != line["body"]
      [:changed, unscored_attributes( active )]
    elsif status == ExemplarIdentificationScore::PENDING
      [:incomplete, unscored_attributes( active ).merge( "last_error" => line["error"] )]
    elsif RESULT_STATUSES.include?( status )
      [status.to_sym, unscored_attributes( active ).merge( result_attributes( line ) )]
    else
      raise "Unknown status #{status.inspect} for id #{line['id']} in #{@path}"
    end
  end

  def unscored_attributes( active )
    ExemplarIdentificationScore::RESULT_ATTRIBUTES.index_with( nil ).merge(
      "status" => active ? ExemplarIdentificationScore::PENDING : ExemplarIdentificationScore::ON_HOLD,
      "flags" => [],
      "attempts" => 0,
      "last_error" => nil
    )
  end

  def reset( identification_ids )
    return 0 if identification_ids.empty?

    write_rejects( identification_ids.map {| id | [id, :reset_edited, RESET_EDITED_DETAIL] } )
    rows = ExemplarIdentificationScore.
      joins( :exemplar_identification ).
      where( exemplar_identifications: { identification_id: identification_ids } )
    [true, false].sum do | active |
      rows.
        where( exemplar_identifications: { active: active } ).
        update_all( unscored_attributes( active ).merge( "updated_at" => Time.now ) )
    end
  end

  # Returns the exemplar_identification_id of the rows inserted
  def insert( rows )
    return [] if rows.empty?

    ExemplarIdentificationScore.
      insert_all( rows, unique_by: :exemplar_identification_id, returning: %w(exemplar_identification_id) ).
      rows.flatten
  end

  # Same as ExemplarIdentificationScoringRun: the body as written to the file
  def sanitize_text( str )
    s = str.to_s
    s = s.gsub( /\r\n?|\n/, " " )
    s = s.gsub( /[\p{Cntrl}&&[^\r\n\t]]/, "" )
    s.gsub( /\s+/, " " ).strip
  end

  # Same as ExemplarIdentificationScoringRun, with the date of the initial run
  def result_attributes( line )
    attributes = ExemplarIdentificationScoringRun::SCORE_COLUMNS.index_with {| column | line[column].presence&.to_i }
    attributes.merge(
      "status" => line["status"],
      "flags" => line["flags"].to_s.split( ExemplarIdentificationScoringRun::FLAG_SEPARATOR ),
      "raw_votes" => line["raw_votes"].presence && JSON.parse( line["raw_votes"] ),
      "filter_model" => line["filter_model"].presence,
      "score_model" => line["score_model"].presence,
      "prompt_version" => line["prompt_version"].presence,
      "scored_at" => Time.parse( line["scored_at"] ),
      "last_error" => nil
    )
  end

  def write_rejects( rejects )
    return if rejects.empty?

    new_file = !File.exist?( rejects_path ) || File.empty?( rejects_path )
    CSV.open( rejects_path, "ab", encoding: "UTF-8" ) do | csv |
      csv << ExemplarIdentificationScoringRun::REJECTS_HEADERS if new_file
      rejects.each {| reject | csv << reject }
    end
  end

  def each_batch
    changed = 0
    ExemplarIdentificationScore.in_batches( of: BATCH_SIZE ) do | batch |
      changed += yield( batch )
    end
    changed
  end
end
