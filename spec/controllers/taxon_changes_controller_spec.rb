require File.dirname(__FILE__) + '/../spec_helper'

describe TaxonChangesController, "commit_records" do
  it "should work for multuple records" do
    tc = make_taxon_swap
    u = User.make!
    sign_in u
    observations = []
    3.times do
      observations << Observation.make!(user: u, taxon: tc.input_taxon)
    end
    put :commit_records, 
      taxon_change_id: tc.id, 
      taxon_id: tc.output_taxon.id,
      type: 'observations',
      record_ids: observations.map(&:id)
    observations.each do |o|
      o.reload
      expect(o.taxon).to eq tc.output_taxon
    end
  end
end
