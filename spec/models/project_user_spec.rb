require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectUser do
  describe "deletion" do
    it "should not work for the project's admin" do
      project = Project.make
      project_user = project.project_users.find_by_user_id(project.user_id)
      assert_raise RuntimeError do
        project_user.destroy
      end
    end
  end
  
  describe "update_taxa_counter_cache" do
    it "should set taxa_count to the number of observed species" do
      project_user = ProjectUser.make
      taxon = Taxon.make(:rank => "species")
      lambda {
        project_observation = ProjectObservation.make(
          :observation => Observation.make(:user => project_user.user, :taxon => taxon), 
          :project => project_user.project)
        project_user.update_taxa_counter_cache
        project_user.reload
      }.should change(project_user, :taxa_count).by(1)
    end
  end
  
  describe "update_observations_counter_cache" do
    it "should set observations_count to the number of observed species" do
      project_user = ProjectUser.make
      taxon = Taxon.make(:rank => "species")
      lambda {
        project_observation = ProjectObservation.make(
          :observation => Observation.make(:user => project_user.user, :taxon => taxon), 
          :project => project_user.project)
        project_user.update_observations_counter_cache
        project_user.reload
      }.should change(project_user, :observations_count).by(1)
    end
  end
end
