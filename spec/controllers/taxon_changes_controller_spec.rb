require File.dirname(__FILE__) + '/../spec_helper'

describe TaxonChangesController, "destroy" do
  let(:tc) { make_taxon_swap }
  before do
    sign_in tc.user
  end
  it "should be possible if not committed" do
    delete :destroy, params: { id: tc.id }
    expect( TaxonChange.find_by_id( tc.id ) ).to be_blank
  end
  it "should not be possible if committed" do
    tc.committer = tc.user
    tc.commit
    delete :destroy, params: { id: tc.id }
    expect( TaxonChange.find_by_id( tc.id ) ).not_to be_blank
  end
end

describe TaxonChangesController, "commit_records" do
  let(:tc) { make_taxon_swap }
  let(:u) { User.make! }
  before do
    sign_in u
  end
  elastic_models( Observation, Identification )

  it "should work for multiple records" do
    observations = []
    3.times do
      observations << Observation.make!(user: u, taxon: tc.input_taxon)
    end
    put :commit_records, params: {
      taxon_change_id: tc.id,
      taxon_id: tc.output_taxon.id,
      type: "observations",
      record_ids: observations.map(&:id)
    }
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
    put :commit_records, params: {
      taxon_change_id: tc.id,
      taxon_id: tc.output_taxon.id,
      type: 'identifications_for_others',
      record_ids: identifications.map(&:id)
    }
    identifications.each do |record|
      record.reload
      expect( record.observation.identifications.by(u).last.taxon ).to eq tc.output_taxon
    end
  end

  it "should not update identifications on your own observations" do
    identifications = []
    3.times do
      # identifications << Identification.make!(user: u, taxon: tc.input_taxon)
      obs = create( :observation, user: u )
      identifications << create( :identification, observation: obs, user: u, taxon: tc.input_taxon )
    end
    put :commit_records, params: {
      taxon_change_id: tc.id,
      taxon_id: tc.output_taxon.id,
      type: 'identifications',
      record_ids: identifications.map(&:id)
    }
    identifications.each do |record|
      record.reload
      expect( record.observation.identifications.by(u).last.taxon ).not_to eq tc.output_taxon
    end
  end
end
