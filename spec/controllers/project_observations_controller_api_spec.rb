require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a ProjectObservationsController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make!(:user => user) }
  let(:project) { Project.make! }
  before(:each) do
    @project_user = ProjectUser.make!(:user => user, :project => project)
  end

  describe "create" do
    it "should work" do
      project.users.should include(user)
      lambda {
        post :create, :format => :json, :project_observation => {
          :observation_id => observation.id,
          :project_id => project.id
        }
      }.should change(ProjectObservation, :count).by(1)
    end

    it "should yield JSON for invalid record" do
      lambda {
        post :create, :format => :json, :project_observation => {
          :project_id => project.id
        }
      }.should_not raise_error
    end

    it "should yield JSON for invalid record if rules" do
      project.project_observation_fields.create(:observation_field => ObservationField.make!, :required => true)
      lambda {
        post :create, :format => :json, :project_observation => {
          :project_id => project.id
        }
      }.should_not raise_error
    end

    describe "with project_id" do
      let(:new_project) { Project.make! }
      it "should add project observation" do
        lambda {
          post :create, :format => :json, :project_id => new_project.id, :project_observation => {
            :observation_id => observation.id,
            :project_id => new_project.id
          }
        }.should change(ProjectObservation, :count).by(1)
      end

      it "should add project user" do
        new_project.project_users.where(:user_id => user.id).should be_blank
        post :create, :format => :json, :project_id => new_project.id, :project_observation => {
          :observation_id => observation.id,
          :project_id => new_project.id
        }
        new_project.project_users.where(:user_id => user.id).should_not be_blank
      end
    end
  end

  it "should destroy" do
    po = ProjectObservation.make!(:observation => observation, :project => project)
    delete :destroy, :format => :json, :id => po.id
    ProjectObservation.find_by_id(po.id).should be_blank
  end
end

describe ProjectObservationsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "a ProjectObservationsController"
end

describe ProjectObservationsController, "devise authentication" do
  before do
    http_login user
  end
  it_behaves_like "a ProjectObservationsController"
end
