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
  
  describe "updating role" do
    before(:each) do
      @project_user = ProjectUser.make
      Delayed::Job.delete_all
      @now = Time.now
    end
    
    it "should queue a job to update identifications if became curator" do
      @project_user.update_attributes(:role => ProjectUser::CURATOR)
      jobs = Delayed::Job.all(:conditions => ["created_at >= ?", @now])
      jobs.select{|j| j.handler =~ /;Project.*update_curator_idents_on_make_curator/m}.should_not be_blank
    end
    
    it "should queue a job to update identifications if became manager" do
      @project_user.update_attributes(:role => ProjectUser::MANAGER)
      jobs = Delayed::Job.all(:conditions => ["created_at >= ?", @now])
      jobs.select{|j| j.handler =~ /;Project.*update_curator_idents_on_make_curator/m}.should_not be_blank
    end
    
    it "should queue a job to update identifications if no longer curator" do
      @project_user.update_attributes(:role => ProjectUser::CURATOR)
      Delayed::Job.delete_all
      @project_user.update_attributes(:role => nil)
      jobs = Delayed::Job.all(:conditions => ["created_at >= ?", @now])
      jobs.select{|j| j.handler =~ /;Project.*update_curator_idents_on_remove_curator/m}.should_not be_blank
    end
    
    it "should not queue a job to update identifications if moving btwn manager and curator" do
      @project_user.update_attributes(:role => ProjectUser::CURATOR)
      Delayed::Job.delete_all
      @project_user.update_attributes(:role => ProjectUser::MANAGER)
      jobs = Delayed::Job.all(:conditions => ["created_at >= ?", @now])
      jobs.select{|j| j.handler =~ /;Project.*update_curator_idents_on_remove_curator/m}.should be_blank
      jobs.select{|j| j.handler =~ /;Project.*update_curator_idents_on_make_curator/m}.should be_blank
    end
  end
end
