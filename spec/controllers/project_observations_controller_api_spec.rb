require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a ProjectObservationsController" do
  let(:user) { make_user_with_privilege( UserPrivilege::ORGANIZER ) }
  let(:observation) { Observation.make!(user: user) }
  let(:project) { Project.make! }
  let(:project_user) { ProjectUser.make!(user: user, project: project) }
  before do
    project_user
  end

  describe "create" do
    elastic_models( Observation )
    it "should work" do
      expect(project.users).to include(user)
      expect {
        post :create, format: :json, params: { project_observation: {
          observation_id: observation.id,
          project_id: project.id
        } }
      }.to change(ProjectObservation, :count).by(1)
    end

    it "should succeed if there is an existing project observation" do
      po = ProjectObservation.make!( observation: observation, project: project )
      post :create, format: :json, params: { project_observation: {
        observation_id: observation.id,
        project_id: project.id
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["id"] ).to eq po.id
    end

    it "should yield JSON for invalid record" do
      expect {
        post :create, format: :json, params: { project_observation: {
          project_id: project.id
        } }
      }.not_to raise_error
    end

    it "should yield JSON for invalid record if rules" do
      project.project_observation_fields.create(observation_field: ObservationField.make!, required: true)
      expect {
        post :create, format: :json, params: { project_observation: {
          project_id: project.id
        } }
      }.not_to raise_error
    end

    it "should update the observation in the elastic index" do
      expect( observation.projects ).to be_blank
      expect( Observation.elastic_query(projects: [project.id]) ).to be_blank
      post :create, format: :json, params: { project_observation: {
        observation_id: observation.id,
        project_id: project.id
      } }
      observation.reload
      expect( observation.projects ).not_to be_blank
      expect( Observation.elastic_query(projects: [project.id]) ).not_to be_blank
    end

    describe "with project_id" do
      let(:new_project) { Project.make! }
      it "should add project observation" do
        expect {
          post :create, format: :json, params: { project_id: new_project.id, project_observation: {
            observation_id: observation.id,
            project_id: new_project.id
          } }
        }.to change(ProjectObservation, :count).by(1)
      end

      it "should add project user" do
        expect(new_project.project_users.where(user_id: user.id)).to be_blank
        post :create, format: :json, params: { project_id: new_project.id, project_observation: {
          observation_id: observation.id,
          project_id: new_project.id
        } }
        expect(new_project.project_users.where(user_id: user.id)).not_to be_blank
      end
    end

    it "should set the user_id" do
      o = Observation.make!
      project_user.update(role: ProjectUser::CURATOR)
      post :create, format: :json, params: { project_observation: {observation_id: o.id, project_id: project.id} }
      po = o.project_observations.last
      expect( po.user_id ).to eq user.id
    end

    it "should not allow addition to invite-only projects if the observer wasn't invited" do
      o = Observation.make!
      project_user.update(role: ProjectUser::CURATOR)
      p = Project.make!(preferred_membership_model: Project::MEMBERSHIP_INVITE_ONLY, user: user)
      post :create, format: :json, params: { project_observation: { observation_id: o.id, project_id: p.id } }
      expect( p.observations ).not_to include o
    end

    it "should allow addition to projects if the observer isn't a member" do
      o = Observation.make!
      project_user.update(role: ProjectUser::CURATOR)
      expect(project.users.where(id: o.user_id)).to be_blank
      post :create, format: :json, params: { project_observation: { observation_id: o.id, project_id: project.id } }
      expect( project.observations ).to include o
    end

    describe "with user preferences" do
      let(:other_observation) { Observation.make! }
      it "should work for people other than the observer" do
        pu = ProjectUser.make!(project: project, user: other_observation.user)
        project_user.update(role: ProjectUser::CURATOR)
        post :create, format: :json, params: {
          project_observation: { project_id: project.id, observation_id: other_observation.id }
        }
        other_observation.reload
        expect(other_observation.projects.to_a).to include project
      end
      it "should work for projects the observer hasn't joined" do
        project_user.update(role: ProjectUser::CURATOR)
        post :create, format: :json, params: {
          project_observation: { project_id: project.id, observation_id: other_observation.id }
        }
        other_observation.reload
        expect(other_observation.projects.to_a).to include project
      end
      it "should not allow non-observers if the observer doesn't allow it" do
        project_user.update(role: ProjectUser::CURATOR)
        other_observation.user.update(preferred_project_addition_by: User::PROJECT_ADDITION_BY_NONE)
        post :create, format: :json, params: {
          project_observation: { project_id: project.id, observation_id: other_observation.id }
        }
        other_observation.reload
        expect(other_observation.projects.to_a).not_to include project
      end
      it "should not allow addition to projects the observer hasn't joined if the observer doesn't allow it" do
        project_user.update(role: ProjectUser::CURATOR)
        other_observation.user.update(preferred_project_addition_by: User::PROJECT_ADDITION_BY_JOINED)
        post :create, format: :json, params: {
          project_observation: { project_id: project.id, observation_id: other_observation.id }
        }
        other_observation.reload
        expect(other_observation.projects.to_a).not_to include project
      end
    end

    it "should not allow setting preferences if creator is not the observer" do
      o = Observation.make!
      post :create, format: :json, params: {
        project_observation: { observation_id: o.id, project_id: project.id, prefers_curator_coordinate_access: true }
      }
      o.reload
      po = o.project_observations.first
      expect( po ).not_to be_prefers_curator_coordinate_access
    end

    it "should return 422 when project_observation parameter not specified" do
      post :create, format: :json
      expect( response.status ).to eq 422
    end
  end

  describe "update" do
    elastic_models( Observation )
    let(:po) { ProjectObservation.make!( project: project ) }
    it "should not allow setting preferences if updater is not the observer" do
      expect( po ).not_to be_prefers_curator_coordinate_access
      put :update, format: :json, params: { id: po.id, project_observation: { prefers_curator_coordinate_access: true } }
      po.reload
      expect( po ).not_to be_prefers_curator_coordinate_access
    end
    it "should return 422 when project_observation parameter not specified" do
      post :update, format: :json, params: { id: po.id }
      expect( response.status ).to eq 422
    end
  end

  describe "destroy" do
    elastic_models( Observation )
    it "should work for the observer" do
      po = ProjectObservation.make!(observation: observation, project: project, user: observation.user)
      delete :destroy, format: :json, params: { id: po.id }
      expect(ProjectObservation.find_by_id(po.id)).to be_blank
    end
    it "should work for a project curator" do
      po = ProjectObservation.make!(observation: observation, project: project, user: observation.user)
      project_user.update(role: ProjectUser::CURATOR)
      delete :destroy, format: :json, params: { id: po.id }
      expect(ProjectObservation.find_by_id(po.id)).to be_blank
    end
    it "should not work for anyone else" do
      pu = ProjectUser.make!
      po = ProjectObservation.make!(project: pu.project)
      expect( project.curated_by?(pu.user) ).to be false
      delete :destroy, format: :json, params: { id: po.id }
      expect( ProjectObservation.find_by_id(po.id) ).not_to be_blank
    end
  end
end

describe ProjectObservationsController, "oauth authentication" do
  let(:token) { double acceptable?: true, accessible?: true, resource_owner_id: user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a ProjectObservationsController"
end
