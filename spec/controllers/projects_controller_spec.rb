require File.dirname(__FILE__) + '/../spec_helper'

describe ProjectsController, "spam" do
  let(:spammer_content) { Project.make!(user: User.make!(spammer: true)) }
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
  before(:each) { enable_elastic_indexing( Project, Place ) }
  after(:each) { disable_elastic_indexing( Project, Place ) }

  describe "for site with a place" do
    let(:place) { make_place_with_geom }
    let(:site) { Site.make!(place: place) }
    before do
      expect(CONFIG).to receive(:site_id).at_least(:once).and_return(site.id)
    end

    it "should filter by place" do
      with_place = Project.make!(place: place)
      without_place = Project.make!(title: "#{with_place.title} without place")
      get :search, q: with_place.title
      expect( assigns(:projects) ).to include with_place
      expect( assigns(:projects) ).not_to include without_place
    end

    it "should allow removal of the place filter" do
      with_place = Project.make!(place: place)
      without_place = Project.make!(title: "#{with_place.title} without place")
      get :search, q: with_place.title, everywhere: true
      expect( assigns(:projects) ).to include with_place
      expect( assigns(:projects) ).to include without_place
    end
  end
end
