require File.dirname(__FILE__) + '/../spec_helper'

describe Goal do
  fixtures :goals,
           :goal_participants,
           :goal_contributions,
           :goal_rules,
           :observations,
           :users
  
  before do
    @goal = goals(:IndividualGoalNotEnded)
  end
  
  it "should run rules against 'thing' and return false when the rules fail" do
    @goal.rules_validate_against?(Taxon.new).should be_false
  end
  
  it "should run rules against 'thing' and return true when the rules pass" do
    obs = Observation.first
    @goal.rules_validate_against?(obs).should be_true
  end
  
  it "should not allow a goal to have an end date in the past" do
    goal = Goal.new({:ends_at   => 5.days.ago, :goal_type => 'community'})
    goal.save.should be_false
    goal.errors.on(:ends_at).should_not be_nil
  end
end

# Community goals
describe Goal, "for the community" do
  fixtures :users,
           :goals,
           :goal_participants,
           :goal_contributions,
           :goal_rules
  
  it "should check to see if it's completed and do nothing" do
    goal = goals(:CommunityNotCompletedNotEnded)
    goal.check_for_completion!
    goal.completed?.should be_false
  end
  
  it "should check to see if it's completed and in fact, complete" do
    goal = goals(:CommunityNotCompletedNotEnded)
    goal.check_for_completion!
    goal.completed?.should be_false
    
    20.times do |i|
      goal.goal_contributions << GoalContribution.new({
        :contribution_id => i,
        :contribution_type => 'Observation',
        :goal_participant_id => 1
      })
    end
    goal.check_for_completion!
    goal.completed?.should be_true
  end
  
  it "should refuse additional contributions when the goal has ended" do
    goal = goals(:CommunityEndedADayAgoNotComplete)
    goal.check_for_completion!
    goal.completed?.should be_false
    
    20.times do |i|
      goal.goal_contributions << GoalContribution.new({
        :contribution_id => i,
        :contribution_type => 'Observation',
        :goal_participant_id => 1
      })
    end
    
    goal.check_for_completion!
    goal.completed?.should be_false
  end
  
  it "should add goal_participant objects to all users when created" do
    user = User.first
    original_num_goals = user.goals.size
    g = Goal.create({:goal_type   => 'community',
                 :description => 'this is a new community goal',
                 :ends_at => 10.days.from_now})
    user.reload
    user.goals.size.should > original_num_goals
  end
end

# Individual goals
describe Goal, "for the individual" do
  fixtures :users,
           :goals,
           :goal_participants,
           :goal_contributions,
           :goal_rules

  it "should raise an exception if asked to check for completetion without a participant object" do
    goal = goals(:IndividualGoalNotEnded)
    lambda {
      goal.completed?.should be_false
      goal.check_for_completion!
    }.should raise_error
  end

  it "should check to see if it is completed and switch a user's " + 
     "participant object to completed after adding another goal " + 
     "contribution" do
    goal = goals(:IndividualGoalNotEnded)
    ted  = User.find_by_login('ted')
    gp = ted.goal_participants.find(:first, :conditions => ["goal_id = ?",
                                                            goal.id])

    # first check to see if the goal itself is marked as completed
    # or if the individual participant is marked as completed
    goal.check_for_completion!(gp)
    goal.completed?.should be_false
    gp.goal_completed?.should be_false
    
    # now let's create a new observation and try the same again
    # the observations should update the goal_participant object
    20.times do |i|
      observation = Observation.create({:user_id => ted.id})
      observation.goal_contributions.should_not be_nil
    end
    
    # this is being called behind the scenes, by Observation
    # but we'll call it here anyways
    goal.check_for_completion!(gp)
    goal.completed?.should be_false
    gp.goal_completed?.should be_true
  end
end
