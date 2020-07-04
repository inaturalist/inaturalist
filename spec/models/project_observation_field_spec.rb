require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservationField, "creation" do
  it "should create a project observation rule if required" do
    pof = ProjectObservationField.make!( required: true )
    expect( pof.project.project_observation_rules ).not_to be_blank
    expect( pof.project.project_observation_rules.last.operator ).to eq "has_observation_field?"
  end
  it "should not create a project observation rule if not required" do
    pof = ProjectObservationField.make!
    expect( pof.project.project_observation_rules ).to be_blank
  end
end

describe ProjectObservationField, "updating" do
  it "should create a project observation rule if required" do
    pof = ProjectObservationField.make!
    pof.update_attributes( required: true )
    expect( pof.project.project_observation_rules ).not_to be_blank
    expect( pof.project.project_observation_rules.last.operator ).to eq "has_observation_field?"
  end

  it "should remove a project observation rule if not required" do
    pof = ProjectObservationField.make!( required: true )
    pof.update_attributes(:required => false)
    expect( pof.project.project_observation_rules ).to be_blank
  end
end

describe ProjectObservationField, "destruction" do
  it "should destroy the project observation rule if required changed to not required" do
    pof = ProjectObservationField.make!( required: true )
    project = pof.project
    pof.destroy
    expect( project.project_observation_rules.detect{|por| por.operator == "has_observation_field?"} ).to be_blank
  end
end
