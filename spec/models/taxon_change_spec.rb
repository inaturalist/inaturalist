require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonChange do
  it { is_expected.to belong_to :source }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to(:taxon).inverse_of :taxon_changes }
  it { is_expected.to belong_to(:committer).class_name 'User' }
  it { is_expected.to have_many(:taxon_change_taxa).inverse_of(:taxon_change).dependent :destroy }
  it { is_expected.to have_many(:taxa).through :taxon_change_taxa }
  it { is_expected.to have_many(:comments).dependent :destroy }
  it { is_expected.to have_many(:identifications).dependent :nullify }

  it { is_expected.to validate_presence_of :taxon_id }

  describe TaxonChange, "find_batched_records_of" do
  describe "observation" do
    elastic_models( Observation )
    it "should only find records identified with input taxa" do
      tc = make_taxon_swap
      obs_of_input_taxon = Observation.make!( taxon: tc.input_taxon )
      obs_not_of_input_taxon = Observation.make!( taxon: Taxon.make! )
      reflection = Taxon.reflections.detect{|k,v| k.to_s == "observations" }[1]
      tc.find_batched_records_of( reflection ) do |batch|
        expect( batch ).to include obs_of_input_taxon
        expect( batch ).not_to include obs_not_of_input_taxon
      end
    end
  end
end
end
