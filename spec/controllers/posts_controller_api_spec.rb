require File.dirname(__FILE__) + '/../spec_helper'
shared_examples_for "a PostsController" do
  describe "routes" do
    it "should accept GET requests" do
      project = Project.make!
      expect(get: "/projects/#{project.id}/journal.json").to be_routable
    end
  end
  describe "index" do
    it "should list journal posts for a project" do
      project = Project.make!
      post = Post.make!(parent: project, user: project.user)
      get :index, format: :json, project_id: project.id
      json = JSON.parse(response.body)
      json_post = json.detect{ |p| p['id'] == post.id }
      expect( json_post ).not_to be_blank
    end
  end
end

describe PostsController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a PostsController"
end

describe PostsController, "devise authentication" do
  let(:user) { User.make! }
  before do
    http_login(user)
  end
  it_behaves_like "a PostsController"
end
