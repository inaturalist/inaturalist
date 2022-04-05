require File.dirname(__FILE__) + '/../spec_helper'

describe UserMutesController do
  let(:user) { User.make! }
  let(:token) { double acceptable?: true, accessible?: true, resource_owner_id: user.id, application: OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  
  describe "create" do
    let(:muted_user) { User.make! }
    it "should add a UserMute" do
      expect( user.user_mutes.size ).to eq 0
      post :create, format: :json, params: { user_mute: { muted_user_id: muted_user.id } }
      user.reload
      expect( user.user_mutes.size ).to eq 1
    end

    it "should return the UserMute as JSON" do
      post :create, format: :json, params: { user_mute: { muted_user_id: muted_user.id } }
      json = JSON.parse( response.body )
      expect( json["id"] ).to eq user.user_mutes.last.id
    end
  end

  describe "destroy" do
    it "should delete a UserMute" do
      um = UserMute.make!( user: user )
      delete :destroy, format: :json, params: { id: um.id }
      expect( UserMute.find_by_id( um.id ) ).to be_blank
    end
  end
end
