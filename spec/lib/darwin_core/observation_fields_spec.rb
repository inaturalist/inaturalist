require "spec_helper"

describe DarwinCore::ObservationFields do
  let(:o) { make_research_grade_observation }
  let(:of) { ObservationField.make! }
  let(:ofv) {
    DarwinCore::ObservationFields.adapt( ObservationFieldValue.make!( observation: o ), observation: o )
  }

  before do
    expect( ofv.observation ).to eq o
  end

  it "should set fieldName to the name of the observation field" do
    expect( ofv.fieldName ).to eq ofv.observation_field.name
  end
  
  it "should set fieldID to the URI of the observation field" do
    expect( ofv.fieldID ).to eq FakeView.observation_field_url( ofv.observation_field )
  end
end
