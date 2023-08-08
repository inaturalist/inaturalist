require "spec_helper"

describe DarwinCore::ResourceRelationship do
  elastic_models( Observation, Taxon )
  let(:o) { make_research_grade_observation }
  let(:of) { ObservationField.make!( datatype: "taxon" ) }
  let(:taxon) { Taxon.make! }
  let(:ofv) {
    DarwinCore::ResourceRelationship.adapt(
      ObservationFieldValue.make!( observation: o, observation_field: of, value: taxon.id ),
      observation: o
    )
  }

  before do
    expect( ofv.observation ).to eq o
  end

  it "should set identifier to the id of the observation field value" do
    expect( ofv.identifier ).to eq ofv.id
  end

  it "should set resourceID to the URI of the observation" do
    expect( ofv.resourceID ).to eq FakeView.observation_url( ofv.observation_id )
  end

  it "should set relationshipOfResourceID to the URI of the observation field" do
    expect( ofv.relationshipOfResourceID ).to eq FakeView.observation_field_url( ofv.observation_field_id )
  end

  it "should set relationshipOfResource to the observation field name" do
    expect( ofv.relationshipOfResource ).to eq ofv.observation_field.name
  end

  it "should set relatedResourceID to the URI of the taxon" do
    expect( ofv.relatedResourceID ).to eq FakeView.taxon_url( ofv.value )
  end

  it "should set relationshipAccordingTo to the URI of the taxon" do
    expect( ofv.relationshipAccordingTo ).to eq FakeView.person_url( ofv.user.login )
  end

  it "should set relationshipEstablishedDate to the date the field value was created" do
    expect( ofv.relationshipEstablishedDate ).to eq ofv.created_at.iso8601
  end
end
