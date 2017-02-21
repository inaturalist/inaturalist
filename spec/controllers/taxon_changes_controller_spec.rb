require File.dirname(__FILE__) + '/../spec_helper'

describe TaxonChangesController, "commit_records" do
  let(:tc) { make_taxon_swap }
  let(:u) { User.make! }
  before do
    sign_in u
  end
  before(:each) { enable_elastic_indexing( Observation, Identification ) }
  after(:each) { disable_elastic_indexing( Observation, Identification ) }

  it "should work for multuple records" do
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

  it "should update identifications" do
    identifications = []
    3.times do
      identifications << Identification.make!(user: u, taxon: tc.input_taxon)
    end
    put :commit_records, 
      taxon_change_id: tc.id, 
      taxon_id: tc.output_taxon.id,
      type: 'identifications_for_others',
      record_ids: identifications.map(&:id)
    identifications.each do |record|
      record.reload
      expect( record.observation.identifications.by(u).last.taxon ).to eq tc.output_taxon
    end
  end
end
