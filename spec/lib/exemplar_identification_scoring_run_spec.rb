# frozen_string_literal: true

require "spec_helper"
require "exemplar_identification_scoring_run"

describe ExemplarIdentificationScoringRun do
  elastic_models( ExemplarIdentification )

  let( :dir ) { Dir.mktmpdir }
  let( :run ) { ExemplarIdentificationScoringRun.new( dir ) }

  after { FileUtils.rm_rf( dir ) }

  before do
    allow_any_instance_of( ExemplarIdentification ).to receive( :set_active ) do | exemplar |
      exemplar.active = true
    end
  end

  def make_score( body: "Note the white wing bars", status: ExemplarIdentificationScore::PENDING, age: 3.days )
    identification = Identification.make!( body: body )
    score = identification.exemplar_identification.exemplar_identification_score
    score.update_columns( status: status, updated_at: age.ago )
    score
  end

  def to_score_rows
    CSV.read( run.to_score_path, headers: true )
  end

  def write_results( *lines )
    headers = %w(id status) + ExemplarIdentificationScoringRun::SCORE_COLUMNS +
      %w(flags raw_votes error filter_model score_model prompt_version)
    CSV.open( run.results_path, "wb" ) do | csv |
      csv << headers
      lines.each {| line | csv << headers.map {| header | line[header] } }
    end
  end

  def rejects( path )
    return [] unless File.exist?( path )

    CSV.read( path, headers: true ).map {| row | row.to_h.values }
  end

  def identification_id( score )
    score.exemplar_identification.identification_id
  end

  def scored_line( score )
    {
      "id" => identification_id( score ),
      "status" => ExemplarIdentificationScore::SCORED,
      "self_contained_score" => 3,
      "self_contained_vote_sum" => 9,
      "readability_score" => 2,
      "readability_vote_sum" => 6,
      "id_help_score" => 1,
      "id_help_vote_sum" => 4,
      "cool_fact_score" => 0,
      "cool_fact_vote_sum" => 0,
      "flags" => "field_mark;similar_species",
      "raw_votes" => { "SC" => [3, 3, 3] }.to_json,
      "filter_model" => "filter-a",
      "score_model" => "model-a",
      "prompt_version" => "v1"
    }
  end

  def failed_line( score )
    {
      "id" => identification_id( score ),
      "status" => ExemplarIdentificationScore::FAILED,
      "error" => "incomplete: 2 of 3 runs returned"
    }
  end

  describe "recover" do
    it "sets submitted rows back to pending without counting an attempt" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      updated_at = score.updated_at
      run.recover
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      expect( score.attempts ).to eq 0
      expect( score.updated_at ).to be_within( 1.second ).of( updated_at )
      expect( rejects( run.export_rejects_path ) ).to eq [
        [identification_id( score ).to_s, "recovered", ExemplarIdentificationScoringRun::RECOVERED_DETAIL]
      ]
    end

    it "leaves other statuses alone" do
      score = make_score( status: ExemplarIdentificationScore::SCORED )
      run.recover
      expect( score.reload.status ).to eq ExemplarIdentificationScore::SCORED
    end
  end

  describe "export" do
    it "marks pending rows older than the minimum age and writes their bodies" do
      score = make_score
      expect( run.export ).to include( marked: 1, written: 1 )
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::SUBMITTED
      expect( score.last_attempt_at ).not_to be_nil
      rows = to_score_rows
      expect( rows.size ).to eq 1
      expect( rows[0]["identification_id"].to_i ).to eq identification_id( score )
      expect( rows[0]["body"] ).to eq "Note the white wing bars"
    end

    it "leaves pending rows younger than the minimum age" do
      score = make_score( age: 1.hour )
      run.export
      expect( score.reload.status ).to eq ExemplarIdentificationScore::PENDING
      expect( to_score_rows.size ).to eq 0
    end

    it "doesn't export rows that aren't pending" do
      make_score( status: ExemplarIdentificationScore::ON_HOLD )
      make_score( status: ExemplarIdentificationScore::SCORED )
      run.export
      expect( to_score_rows.size ).to eq 0
    end

    it "skips short bodies" do
      score = make_score( body: "Nice" )
      expect( run.export ).to include( skipped_short: 1, written: 0 )
      expect( score.reload.status ).to eq ExemplarIdentificationScore::SKIPPED_SHORT
      expect( to_score_rows.size ).to eq 0
      expect( rejects( run.export_rejects_path ) ).to eq [
        [identification_id( score ).to_s, "skipped_short", "1 word(s)"]
      ]
    end

    it "appends to the rejects of the recovery" do
      recovered = make_score( status: ExemplarIdentificationScore::SUBMITTED, age: 1.hour )
      short = make_score( body: "Nice" )
      run.recover
      run.export
      expect( rejects( run.export_rejects_path ).map {| row | row[0].to_i } ).to eq [
        identification_id( recovered ),
        identification_id( short )
      ]
    end

    it "joins the lines of a body" do
      make_score( body: "Note the\nwhite wing bars" )
      run.export
      expect( to_score_rows[0]["body"] ).to eq "Note the white wing bars"
    end
  end

  describe "import" do
    it "stores the result of a scored body" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      score.update_columns( last_error: "an earlier error", attempts: 1 )
      write_results( scored_line( score ) )
      expect( run.import ).to include( scored: 1 )
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::SCORED
      expect( score.self_contained_score ).to eq 3
      expect( score.self_contained_vote_sum ).to eq 9
      expect( score.cool_fact_score ).to eq 0
      expect( score.flags ).to eq %w(field_mark similar_species)
      expect( score.raw_votes ).to eq( { "SC" => [3, 3, 3] } )
      expect( score.score_model ).to eq "model-a"
      expect( score.scored_at ).not_to be_nil
      expect( score.last_error ).to be_nil
      expect( score.attempts ).to eq 1
    end

    it "stores the status of a filtered body" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      write_results( {
        "id" => identification_id( score ),
        "status" => ExemplarIdentificationScore::FILTERED_NO_VALUE,
        "filter_model" => "filter-a",
        "prompt_version" => "v1"
      } )
      run.import
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::FILTERED_NO_VALUE
      expect( score.self_contained_score ).to be_nil
      expect( score.flags ).to eq []
    end

    it "drops the result of a body edited during the run" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      score.update_columns( status: ExemplarIdentificationScore::PENDING )
      write_results( scored_line( score ) )
      expect( run.import ).to include( dropped: 1 )
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      expect( score.self_contained_score ).to be_nil
      expect( rejects( run.import_rejects_path ) ).to eq [
        [identification_id( score ).to_s, "dropped", ExemplarIdentificationScoringRun::DROPPED_DETAIL]
      ]
    end

    it "sets a failed body back to pending with one more attempt" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      write_results( failed_line( score ) )
      expect( run.import ).to include( retried: 1 )
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      expect( score.attempts ).to eq 1
      expect( score.last_error ).to eq "incomplete: 2 of 3 runs returned"
      expect( rejects( run.import_rejects_path ) ).to eq [
        [identification_id( score ).to_s, "retried", "attempt 1 of 3: incomplete: 2 of 3 runs returned"]
      ]
    end

    it "sets a body to failed at the last attempt" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      score.update_columns( attempts: ExemplarIdentificationScoringRun::MAX_ATTEMPTS - 1 )
      write_results( failed_line( score ) )
      expect( run.import ).to include( failed: 1 )
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::FAILED
      expect( score.attempts ).to eq ExemplarIdentificationScoringRun::MAX_ATTEMPTS
      expect( rejects( run.import_rejects_path ) ).to eq [
        [identification_id( score ).to_s, "failed", "attempt 3 of 3: incomplete: 2 of 3 runs returned"]
      ]
    end

    it "counts a body missing from the results as failed" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      write_results
      expect( run.import ).to include( missing: 1 )
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      expect( score.attempts ).to eq 1
      expect( score.last_error ).to eq ExemplarIdentificationScoringRun::MISSING_ERROR
      detail = "attempt 1 of 3: #{ExemplarIdentificationScoringRun::MISSING_ERROR}"
      expect( rejects( run.import_rejects_path ) ).to eq [[identification_id( score ).to_s, "missing", detail]]
    end

    it "can be run again" do
      scored = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      failed = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      write_results( scored_line( scored ), failed_line( failed ) )
      run.import
      run.import
      expect( scored.reload.status ).to eq ExemplarIdentificationScore::SCORED
      expect( failed.reload.attempts ).to eq 1
      expect( rejects( run.import_rejects_path ).map {| row | row[1] } ).to eq %w(retried dropped dropped)
    end

    it "raises on an unknown status" do
      score = make_score( status: ExemplarIdentificationScore::SUBMITTED )
      write_results( { "id" => identification_id( score ), "status" => "unknown" } )
      expect { run.import }.to raise_error( /Unknown status/ )
    end
  end
end
