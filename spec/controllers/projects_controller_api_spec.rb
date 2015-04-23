require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a ProjectsController" do
  let(:user) { User.make! }
  let(:project) { Project.make! }
  before(:each) do
    @project_user = ProjectUser.make!(:user => user, :project => project)
  end

  it "should list joined projects" do
    expect(project.users).to include(user)
    get :by_login, :format => :json, :login => user.login
    expect(response).to be_success
    expect(response.body).to be =~ /#{project.title}/
  end

  describe "join" do
    let(:unjoined_project) { Project.make! }
    it "should add a project user" do
      post :join, format: :json, id: unjoined_project.id
      expect(unjoined_project.users).to include(user)
    end

    it "should set preferred_curator_coordinate_access to observer" do
      p2 = Project.make!
      post :join, format: :json, id: unjoined_project.id
      pu = user.project_users.where(project_id: unjoined_project).first
      expect( pu.preferred_curator_coordinate_access ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER
    end
  end

  describe "leave" do
    it "works" do
      delete :leave, :format => :json, :id => project.id
      project.reload
      expect(project.users).not_to include(user)
    end

    it "should delete project observations by default" do
      without_delay do
        po = make_project_observation(user: user)
        delete :leave, format: :json, id: po.project_id
        expect( ProjectObservation.find_by_id(po.id) ).to be_blank
      end
    end

    it "should allow leaving without deleting project observations" do
      without_delay do
        po = make_project_observation(user: user)
        delete :leave, format: :json, id: po.project_id, keep: "true"
        expect( ProjectObservation.find_by_id(po.id) ).not_to be_blank
      end
    end

    it "should allow leaving with coordinate access revocation" do
      without_delay do
        po = make_project_observation(user: user, prefers_curator_coordinate_access: true)
        expect( po ).to be_prefers_curator_coordinate_access
        delete :leave, format: :json, id: po.project_id, keep: "revoke"
        po.reload
        expect( po ).not_to be_prefers_curator_coordinate_access
      end
    end
  end
end

describe ProjectsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a ProjectsController"
end

describe ProjectsController, "devise authentication" do
  before do
    http_login user
  end
  it_behaves_like "a ProjectsController"
end
