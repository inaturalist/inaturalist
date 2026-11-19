# frozen_string_literal: true

require "spec_helper"
require "exemplar_identification_score_backfill"

describe ExemplarIdentificationScoreBackfill do
  elastic_models( ExemplarIdentification )

  let( :dir ) { Dir.mktmpdir }
  let( :path ) { File.join( dir, "exemplar_identification_backfill.csv" ) }
  let( :started_at ) { 1.minute.ago }
  let( :backfill ) { ExemplarIdentificationScoreBackfill.new( path, started_at: started_at ) }

  after { FileUtils.rm_rf( dir ) }

  before do
    allow_any_instance_of( ExemplarIdentification ).to receive( :set_active ) do | exemplar |
      exemplar.active = true
    end
  end

  let( :headers ) do
    %w(id body status) + ExemplarIdentificationScoringRun::SCORE_COLUMNS +
      %w(flags raw_votes error filter_model score_model prompt_version scored_at)
  end

  # An exemplar identification created before the scores existed: no row
  def make_exemplar( body: "Note the white wing bars", active: true )
    identification = Identification.make!( body: body )
    exemplar = identification.exemplar_identification
    exemplar.exemplar_identification_score.delete
    exemplar.update_columns( active: active )
    exemplar.reload
  end

  def write_file( *lines )
    CSV.open( path, "wb" ) do | csv |
      csv << headers
      lines.each {| line | csv << headers.map {| header | line[header] } }
    end
  end

  def july_line( exemplar, attributes = {} )
    {
      "id" => exemplar.identification_id,
      "body" => exemplar.identification.body,
      "status" => ExemplarIdentificationScore::SCORED,
      "self_contained_score" => 3,
      "self_contained_vote_sum" => 9,
      "readability_score" => 2,
      "readability_vote_sum" => 6,
      "id_help_score" => 1,
      "id_help_vote_sum" => 4,
      "cool_fact_score" => 0,
      "cool_fact_vote_sum" => 0,
      "flags" => "field_mark",
      "raw_votes" => { "SC" => [3, 3, 3], "F" => { "FM" => 3 } }.to_json,
      "filter_model" => "filter-a",
      "score_model" => "model-a",
      "prompt_version" => "abc123",
      "scored_at" => "2026-07-27T00:00:00Z"
    }.merge( attributes )
  end

  def rejects
    return [] unless File.exist?( backfill.rejects_path )

    CSV.read( backfill.rejects_path, headers: true ).map {| row | row.to_h.values }
  end

  def score_of( exemplar )
    ExemplarIdentificationScore.find_by( exemplar_identification_id: exemplar.id )
  end

  describe "import" do
    it "imports the result of an unchanged body" do
      exemplar = make_exemplar
      write_file( july_line( exemplar ) )
      expect( backfill.import ).to include( scored: 1 )
      expect( rejects ).to eq []
      score = score_of( exemplar )
      expect( score.status ).to eq ExemplarIdentificationScore::SCORED
      expect( score.self_contained_vote_sum ).to eq 9
      expect( score.flags ).to eq %w(field_mark)
      expect( score.raw_votes ).to eq( { "SC" => [3, 3, 3], "F" => { "FM" => 3 } } )
      expect( score.score_model ).to eq "model-a"
      expect( score.prompt_version ).to eq "abc123"
      expect( score.scored_at ).to eq Time.utc( 2026, 7, 27 )
    end

    it "keeps a skipped status whatever the active flag" do
      exemplar = make_exemplar( active: false )
      write_file( july_line( exemplar, "status" => ExemplarIdentificationScore::SKIPPED_DUPLICATE ) )
      backfill.import
      expect( score_of( exemplar ).status ).to eq ExemplarIdentificationScore::SKIPPED_DUPLICATE
    end

    it "compares the body as written to the file" do
      exemplar = make_exemplar( body: "Note the\nwhite wing bars" )
      write_file( july_line( exemplar, "body" => "Note the white wing bars" ) )
      expect( backfill.import ).to include( scored: 1 )
    end

    it "sets a changed body to pending without scores" do
      exemplar = make_exemplar
      write_file( july_line( exemplar, "body" => "An older body" ) )
      expect( backfill.import ).to include( changed: 1 )
      expect( rejects ).to eq [[exemplar.identification_id.to_s, "changed", "body changed since the initial run"]]
      score = score_of( exemplar )
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      expect( score.self_contained_score ).to be_nil
      expect( score.score_model ).to be_nil
    end

    it "sets a changed inactive body on hold" do
      exemplar = make_exemplar( active: false )
      write_file( july_line( exemplar, "body" => "An older body" ) )
      backfill.import
      expect( score_of( exemplar ).status ).to eq ExemplarIdentificationScore::ON_HOLD
    end

    it "sets an incomplete result to pending with its error" do
      exemplar = make_exemplar
      write_file( july_line( exemplar, "status" => ExemplarIdentificationScore::PENDING,
        "error" => "incomplete: 2 of 3 runs returned" ) )
      expect( backfill.import ).to include( incomplete: 1 )
      expect( rejects ).to eq [[exemplar.identification_id.to_s, "incomplete", "incomplete: 2 of 3 runs returned"]]
      score = score_of( exemplar )
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      expect( score.last_error ).to eq "incomplete: 2 of 3 runs returned"
      expect( score.attempts ).to eq 0
      expect( score.self_contained_score ).to be_nil
    end

    it "skips a line without an exemplar" do
      exemplar = make_exemplar
      line = july_line( exemplar )
      exemplar.destroy
      write_file( line )
      expect( backfill.import ).to include( no_exemplar: 1 )
      expect( rejects.map {| row | row[1] } ).to eq %w(no_exemplar)
    end

    it "never overwrites an existing row" do
      exemplar = make_exemplar
      exemplar.create_score
      write_file( july_line( exemplar ) )
      expect( backfill.import ).to include( existing: 1 )
      expect( score_of( exemplar ).status ).to eq ExemplarIdentificationScore::PENDING
      expect( rejects.map {| row | row[1] } ).to eq %w(existing)
    end

    it "raises on an unknown status" do
      exemplar = make_exemplar
      write_file( july_line( exemplar, "status" => "unknown" ) )
      expect { backfill.import }.to raise_error( /Unknown status/ )
    end
  end

  describe "fill_gaps" do
    it "gives exemplars without a row a pending or on_hold row" do
      active = make_exemplar
      inactive = make_exemplar( active: false )
      expect( backfill.fill_gaps ).to eq 2
      expect( score_of( active ).status ).to eq ExemplarIdentificationScore::PENDING
      expect( score_of( inactive ).status ).to eq ExemplarIdentificationScore::ON_HOLD
    end

    it "leaves existing rows alone" do
      exemplar = make_exemplar
      write_file( july_line( exemplar ) )
      backfill.import
      expect( backfill.fill_gaps ).to eq 0
      expect( score_of( exemplar ).status ).to eq ExemplarIdentificationScore::SCORED
    end
  end

  describe "reset_edited" do
    it "resets rows whose body was edited after the start" do
      exemplar = make_exemplar
      write_file( july_line( exemplar ) )
      backfill.import
      exemplar.identification.update_columns( body: "Note the black wing bars", updated_at: Time.now )
      expect( backfill.reset_edited ).to eq 1
      expect( rejects.map {| row | row[1] } ).to eq %w(reset_edited)
      score = score_of( exemplar )
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      expect( score.self_contained_score ).to be_nil
      expect( score.flags ).to eq []
    end

    it "leaves rows updated after the start without a body change" do
      exemplar = make_exemplar
      write_file( july_line( exemplar ) )
      backfill.import
      exemplar.identification.update_columns( updated_at: Time.now )
      expect( backfill.reset_edited ).to eq 0
      expect( score_of( exemplar ).status ).to eq ExemplarIdentificationScore::SCORED
    end

    it "leaves rows whose identification wasn't updated after the start" do
      exemplar = make_exemplar
      write_file( july_line( exemplar ) )
      backfill.import
      exemplar.identification.update_columns( body: "Note the black wing bars", updated_at: 1.hour.ago )
      expect( backfill.reset_edited ).to eq 0
      expect( score_of( exemplar ).status ).to eq ExemplarIdentificationScore::SCORED
    end
  end

  describe "reconcile_active" do
    it "follows the current active flag" do
      activated = make_exemplar( active: false )
      deactivated = make_exemplar
      backfill.fill_gaps
      activated.update_columns( active: true )
      deactivated.update_columns( active: false )
      expect( backfill.reconcile_active ).to eq 2
      expect( score_of( activated ).status ).to eq ExemplarIdentificationScore::PENDING
      expect( score_of( deactivated ).status ).to eq ExemplarIdentificationScore::ON_HOLD
    end
  end

  describe "delete_orphans" do
    it "deletes rows whose exemplar or identification no longer exists" do
      kept = make_exemplar
      without_exemplar = make_exemplar
      without_identification = make_exemplar
      backfill.fill_gaps
      ExemplarIdentification.where( id: without_exemplar.id ).delete_all
      Identification.where( id: without_identification.identification_id ).delete_all
      expect( backfill.delete_orphans ).to eq 2
      expect( score_of( kept ) ).not_to be_nil
    end
  end

  describe "row_check" do
    it "reports exemplars without a row" do
      make_exemplar
      expect( backfill.row_check ).to include( difference: 1 )
      backfill.fill_gaps
      expect( backfill.row_check ).to include( difference: 0 )
    end
  end
end
