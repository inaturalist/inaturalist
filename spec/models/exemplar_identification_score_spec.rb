# frozen_string_literal: true

require "spec_helper"

describe ExemplarIdentificationScore do
  include ActiveSupport::Testing::TimeHelpers

  elastic_models( ExemplarIdentification )

  it { is_expected.to belong_to( :exemplar_identification ) }
  it { is_expected.to validate_inclusion_of( :status ).in_array( ExemplarIdentificationScore::STATUSES ) }

  # Forces the exemplar's active flag, which otherwise depends on the taxon,
  # the community taxon, flags and moderation
  def stub_active( active )
    allow_any_instance_of( ExemplarIdentification ).to receive( :set_active ) do | exemplar |
      exemplar.active = active
    end
  end

  def mark_scored( score )
    score.update!(
      status: ExemplarIdentificationScore::SCORED,
      self_contained_score: 3,
      self_contained_vote_sum: 9,
      flags: ["field_mark"],
      raw_votes: { "SC" => [3, 3, 3] },
      score_model: "model-a",
      scored_at: 1.day.ago,
      attempts: 1,
      last_error: "incomplete: 2 of 3 runs returned"
    )
  end

  describe "when an identification body is created" do
    it "creates a pending row when the exemplar is active" do
      stub_active( true )
      identification = Identification.make!( body: "Note the white wing bars" )
      score = identification.exemplar_identification.exemplar_identification_score
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
    end

    it "creates an on_hold row when the exemplar is inactive" do
      stub_active( false )
      identification = Identification.make!( body: "Note the white wing bars" )
      score = identification.exemplar_identification.exemplar_identification_score
      expect( score.status ).to eq ExemplarIdentificationScore::ON_HOLD
    end

    it "creates exactly one row" do
      stub_active( true )
      Identification.make!( body: "Note the white wing bars" )
      expect( ExemplarIdentificationScore.count ).to eq 1
    end

    it "creates no row for an identification without a body" do
      Identification.make!( body: nil )
      expect( ExemplarIdentificationScore.count ).to eq 0
    end

    it "creates a pending row when a body is added to an identification" do
      stub_active( true )
      identification = Identification.make!( body: nil )
      identification.update!( body: "Note the white wing bars" )
      score = identification.exemplar_identification.exemplar_identification_score
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
    end
  end

  describe "when an identification body is edited" do
    let( :identification ) { Identification.make!( body: "Note the white wing bars" ) }
    let( :score ) { identification.exemplar_identification.exemplar_identification_score }

    before { stub_active( true ) }

    it "queues a scored row again and clears its result" do
      mark_scored( score )
      identification.update!( body: "Note the white wing bars and the pale legs" )
      score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::PENDING
      ExemplarIdentificationScore::RESULT_ATTRIBUTES.each do | attribute |
        expect( score.send( attribute ) ).to be_nil
      end
      expect( score.flags ).to eq []
      expect( score.attempts ).to eq 0
      expect( score.last_error ).to be_nil
    end

    it "sets a submitted row back to pending" do
      score.update!( status: ExemplarIdentificationScore::SUBMITTED )
      identification.update!( body: "Note the white wing bars and the pale legs" )
      expect( score.reload.status ).to eq ExemplarIdentificationScore::PENDING
    end

    it "puts the row on_hold when the exemplar is inactive" do
      mark_scored( score )
      stub_active( false )
      identification.update!( body: "Note the white wing bars and the pale legs" )
      expect( score.reload.status ).to eq ExemplarIdentificationScore::ON_HOLD
    end

    it "keeps the result when the body doesn't change" do
      mark_scored( score )
      identification.update!( blind: true )
      expect( score.reload.status ).to eq ExemplarIdentificationScore::SCORED
    end

    it "keeps created_at and updates updated_at" do
      created_at = score.created_at
      travel 1.hour do
        identification.update!( body: "Note the white wing bars and the pale legs" )
        score.reload
        expect( score.created_at ).to be_within( 1.second ).of( created_at )
        expect( score.updated_at ).to be_within( 1.second ).of( Time.now )
      end
    end
  end

  describe "when an identification body is removed" do
    let( :identification ) { Identification.make!( body: "Note the white wing bars" ) }

    it "deletes the row when the body is emptied" do
      expect( identification.exemplar_identification.exemplar_identification_score ).not_to be_nil
      identification.update!( body: "" )
      expect( ExemplarIdentificationScore.count ).to eq 0
    end

    it "deletes the row when the identification is deleted" do
      expect( identification.exemplar_identification.exemplar_identification_score ).not_to be_nil
      identification.destroy
      expect( ExemplarIdentificationScore.count ).to eq 0
    end
  end

  describe "when the exemplar's active flag changes" do
    let!( :exemplar ) do
      stub_active( true )
      Identification.make!( body: "Note the white wing bars" ).exemplar_identification
    end

    def save_with_active( active )
      allow( exemplar ).to receive( :set_active ) { exemplar.active = active }
      exemplar.save!
    end

    it "moves a pending row to on_hold, and back" do
      save_with_active( false )
      expect( exemplar.exemplar_identification_score.reload.status ).to eq ExemplarIdentificationScore::ON_HOLD
      save_with_active( true )
      expect( exemplar.exemplar_identification_score.reload.status ).to eq ExemplarIdentificationScore::PENDING
    end

    it "keeps a scored row scored" do
      mark_scored( exemplar.exemplar_identification_score )
      save_with_active( false )
      score = exemplar.exemplar_identification_score.reload
      expect( score.status ).to eq ExemplarIdentificationScore::SCORED
      expect( score.self_contained_score ).to eq 3
    end

    it "updates updated_at" do
      travel 1.hour do
        save_with_active( false )
        expect( exemplar.exemplar_identification_score.reload.updated_at ).to be_within( 1.second ).of( Time.now )
      end
    end
  end
end
