require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Project, "creation" do
  it "should automatically add the creator as a member" do
    user = User.make
    @project = Project.create(:user => user, :title => "foo")
    @project.project_users.should_not be_empty
    @project.project_users.first.user_id.should == user.id
  end
end