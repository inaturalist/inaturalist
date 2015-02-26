require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a GuidesController" do
  let(:user) { User.make! }

  describe GuidesController, "index" do
    it "should respond to page and per_page" do
      3.times { make_published_guide }
      get :index, :format => :json, :per_page => 2, :page => 2
      json = JSON.parse(response.body)
      expect(json.size).to eq 1
    end
  end

  describe GuidesController, "user" do
    it "should show the guides by the signed in user" do
      guide = Guide.make!(:user => user)
      get :user, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|g| g['id'] == guide.id}).not_to be_blank
    end
  end
end

describe GuidesController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a GuidesController"
end

describe GuidesController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "a GuidesController"
end
