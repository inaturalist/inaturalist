require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservationRule, "validation" do
  it "should add errors to project observation when validation fails" do
    por = ProjectObservationRule.make!(:operator => "identified?")
    po = ProjectObservation.make(:project => por.ruler)
    po.should_not be_valid
  end
end

describe ProjectObservationRule, "creation" do
  it "should not allow more than one operator per project" do
    por1 = ProjectObservationRule.make!(:operator => "identified?")
    por2 = ProjectObservationRule.make(:operator => "identified?", :ruler => por1.ruler)
    por2.should_not be_valid
    por2.errors[:operator].should_not be_blank
  end
end
