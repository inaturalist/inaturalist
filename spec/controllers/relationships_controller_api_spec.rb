require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a RelationshipsController" do
  describe "update" do
    let(:relationship) { Friendship.make!( user: user ) }

    it "should update" do
      expect( relationship ).to be_following
      put :update, format: :json, id: relationship.id, relationship: { following: false }
      expect( response.status ).to eq 200
      relationship.reload
      expect( relationship ).not_to be_following
    end
  end

  describe "destroy" do
    let(:relationship) { Friendship.make!( user: user ) }
    it "should destroy" do
      delete :destroy, format: :json, id: relationship.id
      expect( Friendship.find_by_id( relationship.id ) ).to be_blank
    end
  end
end

describe RelationshipsController, "devise authentication" do
  let(:user) { User.make! }
  before do
    http_login( user )
  end
  it_behaves_like "a RelationshipsController"
end
