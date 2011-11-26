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
