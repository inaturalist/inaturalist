require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectsController, "spam" do
  let(:spammer_content) {
    p = Project.make!
    p.user.update_attributes(spammer: true)
    p
  }
  let(:flagged_content) {
    p = Project.make!
    Flag.make!(flaggable: p, flag: Flag::SPAM)
    p
  }

  it "should render 403 when the owner is a spammer" do
    get :show, id: spammer_content.id
    expect(response.response_code).to eq 403
  end

  it "should render 403 when content is flagged as spam" do
    get :show, id: spammer_content.id
    expect(response.response_code).to eq 403
  end
end

describe ProjectsController, "add" do
  let(:user) { User.make! }
  let(:project_user) { ProjectUser.make!(user: user) }
  let(:project) { project_user.project }
  before do
    sign_in user
  end
  it "should add to the project" do
    o = Observation.make!(user: user)
    post :add, id: project.id, observation_id: o.id
    o.reload
    expect( o.projects ).to include(project)
  end
  it "should set the project observation's user_id" do
    o = Observation.make!(user: user)
    post :add, id: project.id, observation_id: o.id
    o.reload
    expect( o.projects ).to include(project)
    expect( o.project_observations.last.user_id ).to eq user.id
  end
end

describe ProjectsController, "join" do
  let(:user) { User.make! }
  let(:project) { Project.make! }
  before do
    sign_in user
  end
  it "should create a project user" do
    post :join, id: project.id
    expect( project.project_users.where(user_id: user.id).count ).to eq 1
  end
  it "should accept project user parameters" do
    post :join, id: project.id, project_user: {preferred_updates: false}
    pu = project.project_users.where(user_id: user.id).first
    expect( pu ).not_to be_prefers_updates
  end
end

describe ProjectsController, "leave" do
  let(:user) { User.make! }
  let(:project) { Project.make! }
  before do
    sign_in user
  end
  it "should destroy the project user" do
    pu = ProjectUser.make!(user: user, project: project)
    delete :leave, id: project.id
    expect( ProjectUser.find_by_id(pu.id) ).to be_blank
  end
  describe "routes" do
    it "should accept DELETE requests" do
      expect(delete: "/projects/#{project.slug}/leave").to be_routable
    end
  end
end

describe ProjectsController, "search" do
  elastic_models( Project, Place )

  describe "for site with a place" do
    let(:place) { make_place_with_geom }
    before { Site.default.update_attributes(place_id: place.id) }

    it "should filter by place" do
      with_place = Project.make!(place: place)
      without_place = Project.make!(title: "#{with_place.title} without place")
      response_json = <<-JSON
        {
          "results": [
            {
              "record": {
                "id": #{with_place.id}
              }
            }
          ]
        }
      JSON
      stub_request(:get, /#{INatAPIService::ENDPOINT}/).to_return(
        status: 200,
        body: response_json,
        headers: { "Content-Type" => "application/json" }
      )
      get :search, q: with_place.title
      expect( assigns(:projects) ).to include with_place
      expect( assigns(:projects) ).not_to include without_place
    end

    it "should allow removal of the place filter" do
      with_place = Project.make!(place: place)
      without_place = Project.make!(title: "#{with_place.title} without place")
      response_json = <<-JSON
        {
          "results": [
            {
              "record": {
                "id": #{with_place.id}
              }
            },
            {
              "record": {
                "id": #{without_place.id}
              }
            }
          ]
        }
      JSON
      stub_request(:get, /#{INatAPIService::ENDPOINT}/).to_return(
        status: 200,
        body: response_json,
        headers: { "Content-Type" => "application/json" }
      )
      get :search, q: with_place.title, everywhere: true
      expect( assigns(:projects) ).to include with_place
      expect( assigns(:projects) ).to include without_place
    end
  end
end

describe ProjectsController, "update" do
  let(:project) { Project.make! }
  let(:user) { project.user }
  elastic_models( Observation )
  before { sign_in user }
  it "should work for the owner" do
    put :update, id: project.id, project: {title: "the new title"}
    project.reload
    expect( project.title ).to eq "the new title"
  end
  it "allows bioblitz project to turn on aggregation" do
    project.update_attributes(place: make_place_with_geom)
    expect( project ).to be_aggregation_allowed
    expect( project ).not_to be_prefers_aggregation
    put :update, id: project.id, project: { prefers_aggregation: true }
    project.reload
    # still not allowed to aggregate since it's not a Bioblitz project
    expect( project ).not_to be_prefers_aggregation
    put :update, id: project.id, project: {
      prefers_aggregation: true, project_type: Project::BIOBLITZ_TYPE,
      start_time: 5.minutes.ago, end_time: Time.now }
    project.reload
    expect( project ).to be_prefers_aggregation
  end
  it "should not allow a non-curator to turn on observation aggregation" do
    project.update_attributes(place: make_place_with_geom)
    expect( project ).to be_aggregation_allowed
    expect( project ).not_to be_prefers_aggregation
    put :update, id: project.id, project: {prefers_aggregation: true}
    project.reload
    expect( project ).not_to be_prefers_aggregation
  end
  it "should not allow a non-curator to turn off observation aggregation" do
    project.update_attributes(place: make_place_with_geom, prefers_aggregation: true)
    expect( project ).to be_aggregation_allowed
    expect( project ).to be_prefers_aggregation
    put :update, id: project.id, project: {prefers_aggregation: false}
    project.reload
    expect( project ).to be_prefers_aggregation
  end
end

describe ProjectsController, "destroy" do
  let( :project ) { Project.make! }
  before do
    sign_in project.user
  end
  it "should not actually destroy the project" do
    delete :destroy, id: project.id
    expect( Project.find_by_id( project.id ) ).not_to be_blank
  end
  it "should queue a job to destroy the project" do
    delete :destroy, id: project.id
    expect( Delayed::Job.where("handler LIKE '%sane_destroy%'").count ).to eq 1
    expect( Delayed::Job.where("unique_hash = '{:\"Project::sane_destroy\"=>#{project.id}}'").
      count ).to eq 1
  end
end
