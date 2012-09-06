require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservationRule, "validation" do
  it "should add errors to project observation when validation fails" do
    por = ProjectObservationRule.make!(:operator => "identified?")
    po = ProjectObservation.make(:project => por.ruler)
    po.should_not be_valid
  end
end