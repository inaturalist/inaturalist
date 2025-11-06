# frozen_string_literal: true

require "spec_helper"

describe TaxonChange do
  it { is_expected.to belong_to :source }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to( :taxon ).inverse_of :taxon_changes }
  it { is_expected.to belong_to( :committer ).class_name "User" }
  it {
    is_expected.to have_many( :taxon_change_taxa ).inverse_of( :taxon_change ).dependent :destroy
  }
  it { is_expected.to have_many( :taxa ).through :taxon_change_taxa }
  it { is_expected.to have_many( :comments ).dependent :destroy }
  it { is_expected.to have_many( :identifications ).dependent :nullify }

  it { is_expected.to validate_presence_of :taxon_id }

  describe "find_batched_records_of" do
    describe "observation" do
      elastic_models( Observation )
      it "should only find records identified with input taxa" do
        tc = make_taxon_swap
        obs_of_input_taxon = Observation.make!( taxon: tc.input_taxon )
        obs_not_of_input_taxon = Observation.make!( taxon: Taxon.make! )
        reflection = Taxon.reflections.detect {| k, _v | k.to_s == "observations" }[1]
        tc.find_batched_records_of( reflection ) do | batch |
          expect( batch ).to include obs_of_input_taxon
          expect( batch ).not_to include obs_not_of_input_taxon
        end
      end
    end
  end

  describe "Life cannnot be included" do
    let!( :life ) do
      life_taxon = Taxon.make!( name: "Life" )
      stub_const( "Taxon::LIFE", life_taxon )
      life_taxon
    end

    it "cannot include Life as an input taxon for swaps, merges, or splits" do
      [TaxonSwap, TaxonMerge, TaxonSplit].each do | klass |
        taxon_change = klass.make(
          user: make_admin
        )
        taxon_change.committer = taxon_change.user
        taxon_change.add_input_taxon( Taxon::LIFE )
        taxon_change.add_output_taxon( Taxon.make! )
        expect( taxon_change ).not_to be_valid
        expect( taxon_change.errors.any? {| e | e.type == :life_taxon_cannot_be_involved } ).to be true
      end
    end

    it "cannot include Life as an output taxon for swaps, merges, or splits" do
      [TaxonSwap, TaxonMerge, TaxonSplit].each do | klass |
        taxon_change = klass.make(
          user: make_admin
        )
        taxon_change.committer = taxon_change.user
        taxon_change.add_input_taxon( Taxon.make! )
        taxon_change.add_output_taxon( Taxon::LIFE )
        expect( taxon_change ).not_to be_valid
        expect( taxon_change.errors.any? {| e | e.type == :life_taxon_cannot_be_involved } ).to be true
      end
    end

    it "cannot include Life as an input taxon for drops" do
      drop = TaxonDrop.make
      drop.add_input_taxon( Taxon::LIFE )
      expect( drop ).not_to be_valid
      expect( drop.errors.any? {| e | e.type == :life_taxon_cannot_be_involved } ).to be true
    end
  end

  describe "status value and committed_on values are consistent" do
    def build_change
      TaxonSwap.make( user: make_admin )
    end

    it "coerces status to committed when committed_on is present" do
      tc = build_change
      tc.add_input_taxon( Taxon.make! )
      tc.add_output_taxon( Taxon.make! )

      tc.assign_attributes( status: "draft", committed_on: Time.zone.now )
      tc.valid? # triggers before_validation sync

      expect( tc ).to be_valid
      expect( tc.status ).to eq( "committed" )
    end

    it "coerces status away from committed if committed_on is nil" do
      tc = build_change
      tc.add_input_taxon( Taxon.make! )
      tc.add_output_taxon( Taxon.make! )

      tc.assign_attributes( status: "committed", committed_on: nil )
      tc.valid?

      expect( tc ).to be_valid
      expect( tc.status ).not_to eq( "committed" )
      expect( tc.status ).to eq( "draft" )
    end

    it "auto-syncs status to committed if committed_on is set" do
      tc = build_change
      tc.add_input_taxon( Taxon.make! )
      tc.add_output_taxon( Taxon.make! )

      tc.assign_attributes( status: "draft", committed_on: Time.zone.now )
      tc.valid?

      expect( tc.status ).to eq( "committed" )
    end

    it "allows draft with no committed_on" do
      tc = build_change
      tc.add_input_taxon( Taxon.make! )
      tc.add_output_taxon( Taxon.make! )

      tc.assign_attributes( status: "draft", committed_on: nil )
      expect( tc ).to be_valid
    end

    it "does not allow withdrawn with committed_on present (it coerces to committed)" do
      tc = build_change
      tc.add_input_taxon( Taxon.make! )
      tc.add_output_taxon( Taxon.make! )

      tc.assign_attributes( status: "withdrawn", committed_on: Time.zone.now )
      tc.valid?

      # With the auto-sync callback, this will be coerced to committed
      expect( tc ).to be_valid
      expect( tc.status ).to eq( "committed" )
    end
  end
end
