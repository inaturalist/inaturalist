# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "a RelationshipsController" do
  describe "create" do
    let( :friend ) { create :user }
    before do
      user.friendships.destroy_all
    end
    it "should create with trust" do
      expect do
        post :create, format: :json, params: { relationship: { friend_id: friend.id, trust: true } }
      end.to change( user.friendships, :count ).by( 1 )
      user.reload
      expect( user.friendships.last.friend_id ).to eq friend.id
      expect( user.friendships.last ).to be_trust
    end
    it "should create with following" do
      post :create, format: :json, params: { relationship: { friend_id: friend.id, following: false } }
      user.reload
      expect( user.friendships.last.friend_id ).to eq friend.id
      expect( user.friendships.last ).not_to be_following
    end
    it "should create with a UUID" do
      expect do
        post :create, format: :json, params: { relationship: { friend_id: friend.uuid } }
      end.to change( user.friendships, :count ).by( 1 )
    end
  end
  describe "update" do
    let( :relationship ) { Friendship.make!( user: user ) }

    it "should update" do
      expect( relationship ).to be_following
      put :update, format: :json, params: { id: relationship.id, relationship: { following: false } }
      expect( response.status ).to eq 200
      relationship.reload
      expect( relationship ).not_to be_following
    end
  end

  describe "destroy" do
    let( :relationship ) { Friendship.make!( user: user ) }
    it "should destroy" do
      delete :destroy, format: :json, params: { id: relationship.id }
      expect( Friendship.find_by_id( relationship.id ) ).to be_blank
    end
  end
end

describe RelationshipsController, "jwt authentication" do
  let( :user ) { User.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = JsonWebToken.encode( user_id: user.id )
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a RelationshipsController"
end
