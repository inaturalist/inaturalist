require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectObservation, "observed_by_project_member?" do
  
  before(:each) do 
    @project_user = ProjectUser.make
    @project = @project_user.project
    @observation = Observation.make(:user => @project_user.user)
    @po1 = ProjectObservation.make(:project => @project, :observation => @observation)
    @po2 = ProjectObservation.make(:observation => @observation)
  end
  
  it "should be true if observed by a member of the project" do
    @po1.should be_observed_by_project_member
  end
  
  it "should be false unless observed by a member of the project" do
    @po2.should_not be_observed_by_project_member
  end
  
end

describe ProjectObservation, "observed_in_place_bounding_box?" do
  
  it "should work" do
    place = Place.make(:latitude => 0, :longitude => 0, :swlat => -1, :swlng => -1, :nelat => 1, :nelng => 1)
    observation = Observation.make(:latitude => 0.5, :longitude => 0.5)
    project_observation = ProjectObservation.make(:observation => observation)
    project_observation.should be_observed_in_bounding_box_of(place)
  end
  
end
