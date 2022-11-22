# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Friendship do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to(:friend).class_name("User").with_foreign_key "friend_id" }
  it { is_expected.to validate_uniqueness_of(:friend_id).scoped_to :user_id }
  it { is_expected.to validate_presence_of :friend_id }
  it { is_expected.to validate_presence_of :user_id }

  describe Friendship, "creation" do
    describe "subscriptions" do
      before { enable_has_subscribers }
      after { enable_has_subscribers }
      let(:user) { User.make! }
      let(:friend) { User.make! }
      it "should subscribe the user to the friend if following" do
        expect( user.subscriptions.where( resource: friend ).count ).to eq 0
        Friendship.make!( user: user, friend: friend, following: true )
        user.reload
        expect( user.subscriptions.where( resource: friend ).count ).to eq 1
      end
      it "should not subscribe the user to the friend if not following" do
        expect( user.subscriptions.where( resource: friend ).count ).to eq 0
        Friendship.make!( user: user, friend: friend, following: false )
        user.reload
        expect( user.subscriptions.where( resource: friend ).count ).to eq 0
      end
    end
  end

  describe Friendship, "on update," do
    describe "subscriptions" do
      before { enable_has_subscribers }
      after { enable_has_subscribers }
      it "should be removed if following changes to false" do
        friendship = Friendship.make!( following: true )
        expect( friendship.user.subscriptions.where( resource: friendship.friend ).count ).to eq 1
        friendship.update( following: false )
        friendship.reload
        expect( friendship.user.subscriptions.where( resource: friendship.friend ).count ).to eq 0
      end
      it "should be added if following changes to true" do
        friendship = Friendship.make!( following: false )
        expect( friendship.user.subscriptions.where( resource: friendship.friend ).count ).to eq 0
        friendship.update( following: true )
        expect( friendship.user.subscriptions.where( resource: friendship.friend ).count ).to eq 1
      end
    end
  end

  describe Friendship, "on destruction," do
    describe "subscriptions" do
      before { enable_has_subscribers }
      after { enable_has_subscribers }
      it "should be removed" do
        friendship = Friendship.make!( following: true )
        user = friendship.user
        expect( friendship.user.subscriptions.where( resource: friendship.friend ).count ).to eq 1
        friendship.destroy
        user.reload
        expect( user.subscriptions.where( resource: friendship.friend ).count ).to eq 0
      end
    end
  end
end
