require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectUser, "deletion" do
  it "should not work for the project's admin" do
    project = Project.make
    project_user = project.project_users.find_by_user_id(project.user_id)
    assert_raise RuntimeError do
      project_user.destroy
    end
  end
end