require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Project, "creation" do
  it "should automatically add the creator as a member" do
    user = User.make
    @project = Project.create(:user => user, :title => "foo")
    @project.project_users.should_not be_empty
    @project.project_users.first.user_id.should == user.id
  end
  
  it "should not allow ProjectsController action names as titles" do
    project = Project.make
    project.should be_valid
    project.title = "new"
    project.should_not be_valid
    project.title = "user"
    project.should_not be_valid
  end
  
  it "should stip titles" do
    project = Project.make(:title => " zomg spaces ")
    project.title.should == 'zomg spaces'
  end
end

describe Project, "destruction" do
  it "should work despite rule against owner leaving the project" do
    project = Project.make
    assert_nothing_raised do
      project.destroy
    end
  end
end

describe Project, "update_curator_idents_on_make_curator" do
  before(:each) do
    @project = Project.make
  end
  
  it "should set curator_identification_id on existing project observations" do
    po = ProjectObservation.make(:project => @project)
    c = ProjectUser.make(:project => @project, :role => ProjectUser::CURATOR)
    po.curator_identification_id.should be_blank
    ident = Identification.make(:user => c.user, :observation => po.observation)
    Project.update_curator_idents_on_make_curator(@project.id, c.id)
    po.reload
    po.curator_identification_id.should == ident.id
  end
end

describe Project, "update_curator_idents_on_remove_curator" do
  before(:each) do
    @project = Project.make
    @project_observation = ProjectObservation.make(:project => @project)
    @project_user = ProjectUser.make(:project => @project, :role => ProjectUser::CURATOR)
    Identification.make(:user => @project_user.user, :observation => @project_observation.observation)
    Project.update_curator_idents_on_make_curator(@project.id, @project_user.id)
    @project_observation.reload
  end
  
  it "should remove curator_identification_id on existing project observations if no other curator idents" do
    @project_user.update_attributes(:role => nil)
    Project.update_curator_idents_on_remove_curator(@project.id, @project_user.user_id)
    @project_observation.reload
    @project_observation.curator_identification_id.should be_blank
  end
  
  it "should reset curator_identification_id on existing project observations if other curator idents" do
    pu = ProjectUser.make(:project => @project, :role => ProjectUser::CURATOR)
    ident = Identification.make(:observation => @project_observation.observation, :user => pu.user)
    
    @project_user.update_attributes(:role => nil)
    Project.update_curator_idents_on_remove_curator(@project.id, @project_user.user_id)
    
    @project_observation.reload
    @project_observation.curator_identification_id.should == ident.id
  end
  
  it "should work for deleted users" do
    user_id = @project_user.user_id
    @project_user.user.destroy
    Project.update_curator_idents_on_remove_curator(@project.id, user_id)
    @project_observation.reload
    @project_observation.curator_identification_id.should be_blank
  end
end
