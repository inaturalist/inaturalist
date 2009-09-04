require File.dirname(__FILE__) + '/../spec_helper'

# A GoalRule should:
# Be able to call validates? and return only true or false

describe GoalRule do
  fixtures :goal_rules,
           :observations
  
  it "should test a rule and return false" do
    obs = Observation.new
    obs.stub!(:id).and_return(1349857230974532)
    
    rule = goal_rules(:first_five_thousand)
    rule.validates?(obs).should be_false
  end
  
  # this may just test the rule, not the fact that the method returns t / f
  it "should test a rule and return true" do
    obs = Observation.find(:first)
    # obs.should_receive(:id).and_return(2) # I'm not sure what this line was *supposed* to do, but it seemed to be altering the ID of the obs object
    
    rule = goal_rules(:first_five_thousand)
    rule.validates?(obs).should be_true
  end
end
