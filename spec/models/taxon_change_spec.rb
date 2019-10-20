require File.dirname(__FILE__) + '/../spec_helper.rb'

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
