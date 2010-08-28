require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservation, "observed_by_a_member_of?" do
  
  before(:each) do 
    @project_user = ProjectUser.make
    @project = @project_user.project
    @observation = Observation.make(:user => @project_user.user)
    @po1 = ProjectObservation.make(:project => @project, :observation => @observation)
    @po2 = ProjectObservation.make(:observation => @observation)
  end
  
  it "should be true if observed by a member of the project" do
    @po1.should be_observed_by_a_member_of(@project)
  end
  
  it "should be false unless observed by a member of the project" do
    @po2.should_not be_observed_by_a_member_of(@po2.project)
  end
  
end
