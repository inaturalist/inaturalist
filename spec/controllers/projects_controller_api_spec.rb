require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a ProjectsController" do
  let(:user) { User.make! }
  let(:project) { Project.make! }
  before(:each) do
    @project_user = ProjectUser.make!(:user => user, :project => project)
  end

  it "should list joined projects" do
    project.users.should include(user)
    get :by_login, :format => :json, :login => user.login
    response.should be_success
    response.body.should =~ /#{project.title}/
  end

  it "should allow join" do
    p2 = Project.make!
    post :join, :format => :json, :id => p2.id
    p2.users.should include(user)
  end

  it "should allow leave" do
    delete :leave, :format => :json, :id => project.id
    project.reload
    project.users.should_not include(user)
  end
end

describe ProjectsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "a ProjectsController"
end

describe ProjectsController, "devise authentication" do
  before do
    http_login user
  end
  it_behaves_like "a ProjectsController"
end
