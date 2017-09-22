# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + "/../spec_helper"

describe UserBlock do
  let( :user ) { User.make! }
  let( :blocked_user ) { User.make! }
  it "should be valid if there are less than 3 other blocks for this user" do
    2.times { UserBlock.make!( user: user ) }
    expect( UserBlock.make( user: user, blocked_user: blocked_user ) ).to be_valid
  end
  it "should not be balid if there are 3 existing blocks for this user" do
    3.times { UserBlock.make!( user: user ) }
    expect( UserBlock.make( user: user, blocked_user: blocked_user ) ).not_to be_valid
  end
  describe "creation" do
    it "unfollows the user from the blocked user" do
      Friendship.create!( user: user, friend: blocked_user )
      expect( user.friends ).to include blocked_user
      UserBlock.create!( user: user, blocked_user: blocked_user )
      expect( user.friends ).not_to include blocked_user
    end
    it "unfollows the blocked user from the user" do
      Friendship.create!( user: blocked_user, friend: user )
      expect( blocked_user.friends ).to include user
      UserBlock.create!( user: user, blocked_user: blocked_user )
      expect( blocked_user.friends ).not_to include user
    end
  end
  describe "prevents" do
    before do
      @user_block = UserBlock.create!( user: user, blocked_user: blocked_user )
    end
    describe "the blocked user from" do
      it "following the user" do
        expect( Friendship.make( user: blocked_user, friend: user ) ).not_to be_valid
      end
      it "messaging the user" do
        expect( Message.make( user: user, from_user: blocked_user, to_user: user ) ).not_to be_valid
      end
      describe "touching the user's observation" do
        let( :o ) { Observation.make!( user: user ) }
        it "with a commment" do
          expect( Comment.make( user: blocked_user, parent: o ) ).not_to be_valid
        end
        it "with a identification" do
          expect( Identification.make( user: blocked_user, observation: o ) ).not_to be_valid
        end
        it "with a annotations" do
          expect( make_annotation( user: blocked_user, resource: o ) ).not_to be_valid
        end
        it "with a quality metric" do
          expect( QualityMetric.make( user: blocked_user, observation: o ) ).not_to be_valid
        end
        it "with a observation field value" do
          expect( ObservationFieldValue.make( user: blocked_user, observation: o ) ).not_to be_valid
        end
        it "with a project" do
          expect( ProjectObservation.make( user: blocked_user, observation: o ) ).not_to be_valid
        end
        it "with a fave vote" do
          o.vote_by voter: blocked_user, vote: true
          expect( o.cached_votes_total ).to eq 0
        end
        it "with a needs_id vote" do
          o.vote_by voter: blocked_user, vote: true, scope: "needs_id"
          expect( o.cached_votes_total ).to eq 0
        end
      end
    end
    it "notifications for the user when the blocked user comments on an observation the user is following" do
      o = Observation.make!
      Subscription.make!( user: user, resource: o )
      c = Comment.make!( user: blocked_user, parent: o )
      Delayed::Worker.new.work_off
      update_action = UpdateAction.where( resource: o, notifier: c ).first
      expect( update_action ).not_to be_blank
      update_subscriber = UpdateSubscriber.where( update_action: update_action, subscriber: user ).first
      expect( update_subscriber ).to be_blank
    end
    it "notifications for the user when the blocked user identifies an observation the user is following" do
      o = Observation.make!
      Subscription.make!( user: user, resource: o )
      i = Identification.make!( user: blocked_user, observation: o )
      Delayed::Worker.new.work_off
      update_action = UpdateAction.where( resource: o, notifier: i ).first
      expect( update_action ).not_to be_blank
      update_subscriber = UpdateSubscriber.where( update_action: update_action, subscriber: user ).first
      expect( update_subscriber ).to be_blank
    end
  end
end
