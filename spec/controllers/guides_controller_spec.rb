require File.dirname(__FILE__) + '/../spec_helper'

describe GuidesController, "show" do
  describe "published guide" do
    let(:g) { make_published_guide }
    it "should be visible to signed out visitors" do
      get :show, id: g.id
      expect(response).to be_success
    end
  end
  describe "draft guide" do
    let(:g) { Guide.make! }
    before do
      expect(g).not_to be_published
    end
    it "should not be viewable by signed out visitors" do
      get :show, id: g.id
      expect(response).to be_not_found
    end
    it "should not be viewable by any signed in visitor" do
      sign_in User.make!
      get :show, id: g.id
      expect(response).to be_not_found
    end
    it "should be viewable by guide editor if the guide is a draft" do
      gu = GuideUser.make!(guide: g)
      sign_in gu.user
      get :show, id: g.id
      expect(response).to be_success
    end
  end
end

describe GuidesController, "index" do
  it "should filter by place" do
    p1 = Place.make!
    p2 = Place.make!
    g = make_published_guide(place: p1)
    get :index, :place_id => p1.id
    expect(assigns(:guides)).to include g
    get :index, :place_id => p2.id
    expect(assigns(:guides)).not_to include g
  end
end

describe GuidesController, "update" do
  let(:user) { User.make! }
  let(:guide) { make_published_guide(user: user) }
  before do
    sign_in user
  end
  it "should publish the guide based on the publish param" do
    guide.update_attribute(:published_at, nil)
    expect(guide).not_to be_published
    patch :update, id: guide.id, publish: true
    guide.reload
    expect(guide).to be_published
  end
  it "should unpublish the guide" do
    expect(guide).to be_published
    patch :update, id: guide.id, unpublish: true
    guide.reload
    expect(guide).not_to be_published
  end
  it "should change the title" do
    patch :update, id: guide.id, guide: {title: "this is a new title"}
    guide.reload
    expect(guide.title).to eq "this is a new title"
  end
  it "should allow assignment of nested guide users" do
    u = User.make!
    patch :update, id: guide.id, guide: {guide_users_attributes: {"0": {user_id: u.id}}} 
    guide.reload
    expect(guide.guide_users.size).to eq 2
  end
end

describe GuidesController, "import_taxa" do
  describe "from names" do
    before do
      @guide = Guide.make!
      sign_in @guide.user
    end
    it "should add guide taxa" do
      taxa = 3.times.map{Taxon.make!}
      expect(@guide.guide_taxa).to be_blank
      post :import_taxa, id: @guide, names: taxa.map(&:name).join("\n"), format: :json
      @guide.reload
      expect(@guide.guide_taxa.count).to eq 3
    end
  end
end
