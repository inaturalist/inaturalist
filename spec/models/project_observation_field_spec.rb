require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservationField, "creation" do
  it "should create a project observation rule if required" do
    pof = ProjectObservationField.make!(:required => true)
    pof.project.project_observation_rules.should_not be_blank
    pof.project.project_observation_rules.last.operator.should eq('has_observation_field?')
  end
  it "should not create a project observation rule if not required" do
    pof = ProjectObservationField.make!
    pof.project.project_observation_rules.should be_blank
  end
end

describe ProjectObservationField, "destruction" do
  it "should destroy the project observation rule if required changed to not required" do
    pof = ProjectObservationField.make!(:required => true)
    project = pof.project
    pof.destroy
    project.project_observation_rules.detect{|por| por.operator == "has_observation_field?"}.should be_blank
  end
end
