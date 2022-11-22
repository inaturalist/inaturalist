require File.dirname(__FILE__) + '/../spec_helper'

describe CustomProjectsController, "new" do
  let(:project) { Project.make! }
  it "should not allow access to managers if project isn't trusted" do
    expect( project ).not_to be_trusted
    pu = ProjectUser.make!( project: project, role: "manager" )
    sign_in pu.user
    get :new,  params: { project_id: project.id }
    expect( response ).to be_redirect
  end
  
  it "should not allow access to non-managers" do
    project.update( trusted: true )
    u = User.make!
    sign_in u
    get :new,  params: { project_id: project.id }
    expect( response ).to be_redirect
  end

  it "should allow access by managers if project trusted" do
    project.update( trusted: true)
    pu = ProjectUser.make!( project: project, role: "manager" )
    sign_in pu.user
    get :new,  params: { project_id: project.id }
    expect( response ).to be_successful
  end

  it "should allow access by admins" do
    u = make_admin
    sign_in u
    get :new,  params: { project_id: project.id }
    expect( response ).to be_successful
  end
end
