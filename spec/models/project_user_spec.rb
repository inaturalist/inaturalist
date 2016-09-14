require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectUser, "creation" do
  before(:each) { enable_elastic_indexing(UpdateAction) }
  after(:each) { disable_elastic_indexing(UpdateAction) }
  it "should subscribe user to assessment sections if curator" do
    as = AssessmentSection.make!
    p = as.assessment.project
    pu = without_delay do
      ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR)
    end
    expect(pu.user.subscriptions.where(:resource_type => "AssessmentSection", :resource_id => as)).not_to be_blank
  end

  it "should subscribe user to assessment sections if manager" do
    as = AssessmentSection.make!
    p = as.assessment.project
    pu = without_delay do
      ProjectUser.make!(:project => p, :role => ProjectUser::MANAGER)
    end
    expect(pu.user.subscriptions.where(:resource_type => "AssessmentSection", :resource_id => as)).not_to be_blank
  end

  it "should not subscribe user to assessment sections if role blank" do
    as = AssessmentSection.make!
    p = as.assessment.project
    pu = without_delay do
      ProjectUser.make!(:project => p)
    end
    expect(pu.user.subscriptions.where(:resource_type => "AssessmentSection", :resource_id => as)).to be_blank
  end

  it "should set curator_coordinate_access to observer by default" do
    expect( ProjectUser.make!.preferred_curator_coordinate_access ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER
  end

  describe "invite-only projects" do
    let(:project) { Project.make!(:prefers_membership_model => Project::MEMBERSHIP_INVITE_ONLY) }
    
    it "should not be valid for invite-only projects without a project user invitation" do
      pu = ProjectUser.make(:project => project)
      expect(pu).not_to be_valid
    end

    it "should be valid for invite-only projects with a project user invitation" do
      pui = ProjectUserInvitation.make!(:project => project)
      pu = ProjectUser.make!(:project => project, :user => pui.invited_user)
      expect(pu).to be_valid
    end

    it "should be valid for the project owner" do
      u = project.user
      pu = u.project_users.where(project_id: project.id).first
      expect(pu).to be_valid
    end
  end
end

describe ProjectUser do
  before(:each) { enable_elastic_indexing(Observation, Taxon) }
  after(:each) { disable_elastic_indexing(Observation, Taxon) }

  describe "updating curator_coordinate_access" do
    it "should update past project observations from this project" do
      pu = ProjectUser.make!
      expect( pu.project.user ).not_to eq pu.user
      expect( pu.preferred_curator_coordinate_access ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER
      o = Observation.make!( user: pu.user, latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE )
      expect( o ).not_to be_coordinates_viewable_by pu.project.user
      po = ProjectObservation.make!( observation: o, project: pu.project, user: pu.project.user )
      o.reload
      expect( o ).not_to be_coordinates_viewable_by pu.project.user
      pu.update_attributes( preferred_curator_coordinate_access: ProjectUser::CURATOR_COORDINATE_ACCESS_ANY )
      Delayed::Worker.new.work_off
      pu.reload
      expect( pu.preferred_curator_coordinate_access ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_ANY
      o.reload
      expect( o ).to be_coordinates_viewable_by pu.project.user
    end
    it "should not update past project observations from the user's other projects" do
      pu = ProjectUser.make!
      o = Observation.make!( user: pu.user, latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE )
      po = ProjectObservation.make!( observation: o, project: pu.project, user: pu.project.user )

      other_pu = ProjectUser.make!( user: pu.user )
      other_o = Observation.make!( user: other_pu.user, latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE )
      other_po = ProjectObservation.make!( observation: other_o, project: other_pu.project, user: other_pu.project.user )

      pu.update_attributes( preferred_curator_coordinate_access: ProjectUser::CURATOR_COORDINATE_ACCESS_ANY )
      Delayed::Worker.new.work_off
      pu.reload
      o.reload
      expect( o ).to be_coordinates_viewable_by pu.project.user
      expect( other_o ).not_to be_coordinates_viewable_by pu.project.user
    end
  end

  describe "update_taxa_counter_cache" do
    it "should set taxa_count to the number of observed species" do
      project_user = ProjectUser.make!
      taxon = Taxon.make!(:rank => "species")
      expect {
        project_observation = ProjectObservation.make!(
          :observation => Observation.make!(:user => project_user.user, :taxon => taxon), 
          :project => project_user.project)
        project_user.update_taxa_counter_cache
        project_user.reload
      }.to change(project_user, :taxa_count).by(1)
    end

    it "should set taxa_count to number of species observed OR identified by a curator" do
      t = Taxon.make!(:rank => Taxon::SPECIES)
      po = make_project_observation
      pu = po.project.project_users.where(:user_id => po.observation.user_id).first
      expect(pu.taxa_count).to eq 0
      puc = ProjectUser.make!(:project => po.project, :role => ProjectUser::CURATOR)
      i = without_delay do
        Identification.make!(:observation => po.observation, :user => puc.user, :taxon => t)
      end
      po.reload
      expect(po.curator_identification).not_to be_blank
      pu.update_taxa_counter_cache
      pu.reload
      expect(pu.taxa_count).to eq 1
    end
  end
  
  describe "update_observations_counter_cache" do
    it "should set observations_count to the number of observed species" do
      project_user = ProjectUser.make!
      taxon = Taxon.make!(:rank => "species")
      expect {
        project_observation = ProjectObservation.make!(
          :observation => Observation.make!(:user => project_user.user, :taxon => taxon), 
          :project => project_user.project)
        project_user.update_observations_counter_cache
        project_user.reload
      }.to change(project_user, :observations_count).by(1)
    end
  end
  
  describe "updating role" do
    before(:each) do
      @project_user = ProjectUser.make!
      Delayed::Job.delete_all
      @now = Time.now
      enable_elastic_indexing(UpdateAction)
    end
    after(:each) { disable_elastic_indexing(UpdateAction) }
    
    it "should queue a job to update identifications if became curator" do
      @project_user.update_attributes(:role => ProjectUser::CURATOR)
      jobs = Delayed::Job.where("created_at >= ?", @now)
      expect(jobs.select{|j| j.handler =~ /Project.*update_curator_idents_on_make_curator/m}).not_to be_blank
    end
    
    it "should queue a job to update identifications if became manager" do
      @project_user.update_attributes(:role => ProjectUser::MANAGER)
      jobs = Delayed::Job.where("created_at >= ?", @now)
      expect(jobs.select{|j| j.handler =~ /Project.*update_curator_idents_on_make_curator/m}).not_to be_blank
    end
    
    it "should queue a job to update identifications if no longer curator" do
      @project_user.update_attributes(:role => ProjectUser::CURATOR)
      Delayed::Job.delete_all
      @project_user.update_attributes(:role => nil)
      jobs = Delayed::Job.where("created_at >= ?", @now)
      expect(jobs.select{|j| j.handler =~ /Project.*update_curator_idents_on_remove_curator/m}).not_to be_blank
    end
    
    it "should not queue a job to update identifications if moving btwn manager and curator" do
      @project_user.update_attributes(:role => ProjectUser::CURATOR)
      Delayed::Job.delete_all
      @project_user.update_attributes(:role => ProjectUser::MANAGER)
      jobs = Delayed::Job.where("created_at >= ?", @now)
      expect(jobs.select{|j| j.handler =~ /Project.*update_curator_idents_on_remove_curator/m}).to be_blank
      expect(jobs.select{|j| j.handler =~ /Project.*update_curator_idents_on_make_curator/m}).to be_blank
    end

    it "should notify project members of new curators" do
      pu = ProjectUser.make!
      start = Time.now
      curator_pu = without_delay do 
        ProjectUser.make!(:project => pu.project, :role => ProjectUser::CURATOR)
      end
      u = UpdateSubscriber.joins(:update_action).where("created_at >= ?", start).
        where(subscriber_id: pu.user_id).first
      expect(u).not_to be_blank
    end

    it "should notify project members of new managers" do
      pu = ProjectUser.make!
      start = Time.now
      curator_pu = without_delay do 
        ProjectUser.make!(:project => pu.project, :role => ProjectUser::MANAGER)
      end
      u = UpdateSubscriber.joins(:update_action).where("created_at >= ?", start).
        where(subscriber_id: pu.user_id).first
      expect(u).not_to be_blank
    end

    it "should notify project members of new owners" do
      pu = ProjectUser.make!
      p = pu.project
      new_pu = ProjectUser.make!(:project => p)
      start = Time.now
      without_delay do
        p.update_attributes(:user => new_pu.user)
      end
      u = UpdateSubscriber.joins(:update_action).where("created_at >= ?", start).
        where(subscriber_id: pu.user_id).first
      expect(u).not_to be_blank
    end
  end
end

describe ProjectUser, "prefers_updates" do
  it "should allow journal post updates when true"
  it "should supress journal post updates when false"
end
