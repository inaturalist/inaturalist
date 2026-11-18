# frozen_string_literal: true

require "csv"

# The Rails side of a scoring run: recovers the rows of a run that died,
# exports the bodies to score to exemplar_identification_remarks_to_score.csv,
# and imports exemplar_identification_remarks_scored.csv. Both files live in
# the run directory. Rows are read and written in batches, and the files are
# streamed, so memory use stays flat.
#
# The run doesn't touch updated_at: the minimum age is about changes made
# on the site, and the rows of a run that died must be exported again by
# the next run, even right away.
class ExemplarIdentificationScoringRun
  MINIMUM_AGE = 48.hours
  MAX_ATTEMPTS = 3
  MIN_WORDS = 2
  BATCH_SIZE = 1000
  TO_SCORE_FILE = "exemplar_identification_remarks_to_score.csv"
  RESULTS_FILE = "exemplar_identification_remarks_scored.csv"
  MISSING_ERROR = "missing from #{RESULTS_FILE}".freeze

  TO_SCORE_HEADERS = %w(
    identification_id
    body
    taxon_name
    taxon_common_name
    iconic_taxon_name
  ).freeze

  TO_SCORE_COLUMNS = %w(
    exemplar_identification_scores.id
    identifications.id
    identifications.body
    identifications.taxon_id
    taxa.name
    taxa.iconic_taxon_id
  ).freeze

  SCORE_COLUMNS = %w(
    self_contained_score
    self_contained_vote_sum
    readability_score
    readability_vote_sum
    id_help_score
    id_help_vote_sum
    cool_fact_score
    cool_fact_vote_sum
  ).freeze

  RESULT_STATUSES = [
    ExemplarIdentificationScore::SCORED,
    ExemplarIdentificationScore::FILTERED_UNCERTAIN,
    ExemplarIdentificationScore::FILTERED_NO_VALUE
  ].freeze

  FLAG_SEPARATOR = ";"

  def initialize( dir )
    @dir = dir
  end

  def to_score_path
    File.join( @dir, TO_SCORE_FILE )
  end

  def results_path
    File.join( @dir, RESULTS_FILE )
  end

  # Only a run sets rows to submitted, and runs never overlap, so rows still
  # submitted when a run starts belong to a run that died. No attempt is
  # counted: the run failed, not the body
  def recover
    ExemplarIdentificationScore.
      where( status: ExemplarIdentificationScore::SUBMITTED ).
      update_all( status: ExemplarIdentificationScore::PENDING )
  end

  # Marks the rows first, then reads their bodies: a body edited after the
  # marking sets its row back to pending, so it's neither written to the file
  # nor imported
  def export
    marked = mark
    written = 0
    skipped_short = 0
    common_names = {}
    CSV.open( to_score_path, "wb", force_quotes: true, encoding: "UTF-8" ) do | csv |
      csv << TO_SCORE_HEADERS
      submitted.in_batches( of: BATCH_SIZE ) do | batch |
        rows = batch.
          left_joins( exemplar_identification: { identification: :taxon } ).
          pluck( *TO_SCORE_COLUMNS )
        load_common_names( rows.map {| row | row[3] }, common_names )
        short_ids = []
        rows.each do | row |
          score_id, identification_id, body, taxon_id, taxon_name, iconic_taxon_id = row
          body = sanitize_text( body )
          if body.split.size < MIN_WORDS
            short_ids << score_id
            next
          end

          csv << [
            identification_id,
            body,
            taxon_name,
            common_names[taxon_id],
            Taxon::ICONIC_TAXA_BY_ID[iconic_taxon_id]&.name
          ]
          written += 1
        end
        skipped_short += submitted.where( id: short_ids ).
          update_all( status: ExemplarIdentificationScore::SKIPPED_SHORT )
      end
    end
    { marked: marked, written: written, skipped_short: skipped_short }
  end

  # Writes results only to rows still submitted: a row whose body was edited
  # during the run is pending again, and its result is dropped. Rerunning a
  # half-done import is safe for the same reason
  def import
    counts = Hash.new( 0 )
    now = Time.now
    CSV.foreach( results_path, headers: true, encoding: "UTF-8" ).each_slice( BATCH_SIZE ) do | lines |
      score_ids = submitted.
        joins( :exemplar_identification ).
        where( exemplar_identifications: { identification_id: lines.map {| line | line["id"].to_i } } ).
        pluck( "exemplar_identifications.identification_id", :id ).
        to_h
      lines.each do | line |
        score_id = score_ids[line["id"].to_i]
        unless score_id
          counts[:dropped] += 1
          next
        end

        status = line["status"]
        if status == ExemplarIdentificationScore::FAILED
          counts[record_failure( submitted.where( id: score_id ), line["error"] )] += 1
        elsif RESULT_STATUSES.include?( status )
          submitted.where( id: score_id ).update_all( result_attributes( line, now ) )
          counts[status.to_sym] += 1
        else
          raise "Unknown status #{status.inspect} for id #{line['id']} in #{results_path}"
        end
      end
    end
    record_missing( counts )
    counts
  end

  private

  def submitted
    ExemplarIdentificationScore.where( status: ExemplarIdentificationScore::SUBMITTED )
  end

  def mark
    now = Time.now
    marked = 0
    ExemplarIdentificationScore.
      where( status: ExemplarIdentificationScore::PENDING ).
      where( "updated_at < ?", now - MINIMUM_AGE ).
      in_batches( of: BATCH_SIZE ) do | batch |
        marked += batch.update_all( status: ExemplarIdentificationScore::SUBMITTED, last_attempt_at: now )
      end
    marked
  end

  def result_attributes( line, now )
    attributes = SCORE_COLUMNS.index_with {| column | line[column].presence&.to_i }
    attributes.merge(
      status: line["status"],
      flags: line["flags"].to_s.split( FLAG_SEPARATOR ),
      raw_votes: line["raw_votes"].presence && JSON.parse( line["raw_votes"] ),
      filter_model: line["filter_model"].presence,
      score_model: line["score_model"].presence,
      prompt_version: line["prompt_version"].presence,
      scored_at: now,
      last_error: nil
    )
  end

  # A failed body is retried by the next run, until it fails MAX_ATTEMPTS
  # times
  def record_failure( scope, error )
    failed = scope.where( "attempts >= ?", MAX_ATTEMPTS - 1 ).update_all(
      ["status = ?, attempts = attempts + 1, last_error = ?", ExemplarIdentificationScore::FAILED, error]
    )
    scope.update_all(
      ["status = ?, attempts = attempts + 1, last_error = ?", ExemplarIdentificationScore::PENDING, error]
    )
    failed.positive? ? :failed : :retried
  end

  # Rows still submitted after the import were exported by this run but are
  # missing from exemplar_identification_remarks_scored.csv, so nothing can
  # silently disappear
  def record_missing( counts )
    submitted.in_batches( of: BATCH_SIZE ) do | batch |
      counts[:missing] += batch.count
      record_failure( batch, MISSING_ERROR )
    end
  end

  def sanitize_text( str )
    s = str.to_s
    s = s.gsub( /\r\n?|\n/, " " )
    s = s.gsub( /[\p{Cntrl}&&[^\r\n\t]]/, "" )
    s.gsub( /\s+/, " " ).strip
  end

  def load_common_names( taxon_ids, cache )
    missing = taxon_ids.compact.uniq - cache.keys
    return if missing.empty?

    missing.each {| id | cache[id] = nil }
    TaxonName.
      where( taxon_id: missing, is_valid: true ).
      where( lexicon: TaxonName::LEXICONS[:ENGLISH] ).
      order( "taxon_id ASC, position ASC NULLS LAST, id ASC" ).
      pluck( :taxon_id, :name ).
      each {| taxon_id, name | cache[taxon_id] ||= name }
  end
end
