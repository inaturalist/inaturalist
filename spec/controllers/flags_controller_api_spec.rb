require File.dirname(__FILE__) + '/../spec_helper'

describe FlagsController do
  let(:user) { User.make! }
  let(:token) { double acceptable?: true, accessible?: true, resource_owner_id: user.id, application: OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end

  describe "create" do
    let(:comment) { Comment.make! }
    it "should add a flag" do
      expect( comment.flags.size ).to eq 0
      post :create, format: :json, flag: { flaggable_type: "Comment", flaggable_id: comment.id, flag: Flag::SPAM }
      expect( response.status ).to eq 200
      comment.reload
      expect( comment.flags.size ).to eq 1
    end
    it "should return JSON" do
      post :create, format: :json, flag: { flaggable_type: "Comment", flaggable_id: comment.id, flag: Flag::SPAM }
      json = JSON.parse( response.body )
      expect( json["id"] ).to eq comment.flags.last.id
    end
  end

  describe "update" do
    let(:flag) { Flag.make!( user: user ) }
    it "should update a flag" do
      expect( flag ).not_to be_resolved
      put :update, format: :json, id: flag.id, flag: { resolved: true }
      flag.reload
      expect( flag ).to be_resolved
    end

    it "should return JSON" do
      put :update, format: :json, id: flag.id, flag: { resolved: true }
      json = JSON.parse( response.body )
      expect( json["resolved"] ).to eq true
    end
  end
end
