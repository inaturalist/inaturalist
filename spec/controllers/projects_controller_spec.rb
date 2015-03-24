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
