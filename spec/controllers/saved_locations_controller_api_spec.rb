require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a SavedLocationsController" do
  let(:user) { User.make! }

  describe "index" do
    it "shows the current user's saved locations" do
      saved_location = SavedLocation.make!( user: user )
      get :index, format: :json
      expect( JSON.parse( response.body )["results"].detect{|sl| sl["id"] == saved_location.id } ).not_to be_blank
    end
    it "does not show other users' saved locations" do
      saved_location = SavedLocation.make!
      get :index, format: :json
      expect( JSON.parse( response.body )["results"].detect{|sl| sl["id"] == saved_location.id } ).to be_blank
    end
  end

  describe "create" do
    it "should associate a new SavedLocation with the user that created it" do
      post :create, format: :json, saved_location: { title: "foo", latitude: 1, longitude: 1 }
      expect( SavedLocation.last.user ).to eq user
    end
  end
  describe "destroy" do
    it "should not allow deletion of a SavedLocation that does not belong to the authenticated user" do
      sl = SavedLocation.make!
      delete :destroy, format: :json, id: sl.id
      expect( response ).to be_forbidden
      expect( SavedLocation.find_by_id( sl.id ) ).not_to be_blank
    end
  end
end

describe SavedLocationsController, "oauth authentication" do
  let(:token) { double acceptable?: true, accessible?: true, resource_owner_id: user.id, application: OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a SavedLocationsController"
end

