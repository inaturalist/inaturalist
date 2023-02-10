# -*- coding: utf-8 -*-
require File.dirname(__FILE__) + "/../spec_helper"

describe UserMute do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to(:muted_user).class_name "User" }

  it { is_expected.to validate_presence_of :user }
  it { is_expected.to validate_presence_of :muted_user }
  it { is_expected.to validate_uniqueness_of(:muted_user_id).scoped_to(:user_id).with_message "already muted" }

  before { enable_has_subscribers }
  after { disable_has_subscribers }

  let( :user ) { User.make! }
  let( :muted_user ) { User.make! }

  it "marks messages from the muted user as read" do
    user_mute = UserMute.create!( user: user, muted_user: muted_user )
    m = Message.make!( user: user, from_user: muted_user, to_user: user )
    expect( m.read_at ).not_to be_blank
  end
  describe "prevents" do
    before do
      @user_mute = UserMute.create!( user: user, muted_user: muted_user )
    end
    it "delivery of email for new messages" do
      Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
      m = Message.make!( user: user, from_user: muted_user, to_user: user )
      expect {
        Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
      }.not_to change( ActionMailer::Base.deliveries, :count )
    end
    describe "notifications for the user" do
      it "when the muted user mentions the user" do
        o = Observation.make!( user: muted_user, description: "hey @#{user.login}" )
        Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
        update_action = UpdateAction.where( resource: o ).first
        expect( update_action ).not_to be_blank
        expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
      end
      it "when the user follows the muted user and the muted user makes a new observation" do
        Friendship.make!( user: user, friend: muted_user )
        o = Observation.make!( user: muted_user )
        Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
        update_action = UpdateAction.where( resource: muted_user, notifier: o ).first
        expect( update_action ).not_to be_blank
        expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
      end
      it "when the user follows a place and the muted user makes a new observation in that place" do
        p = make_place_with_geom
        Subscription.make!( user: user, resource: p )
        o = Observation.make!( user: muted_user, latitude: p.latitude, longitude: p.longitude )
        Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
        update_action = UpdateAction.where( resource: p, notifier: o ).first
        expect( update_action ).not_to be_blank
        expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
      end
      it "when the user follows a taxon and the muted user makes a new observation of that taxon" do
        t = Taxon.make!
        Subscription.make!( user: user, resource: t )
        o = Observation.make!( user: muted_user, taxon: t )
        Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
        update_action = UpdateAction.where( resource: t, notifier: o ).first
        expect( update_action ).not_to be_blank
        expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
      end
      describe "notifications for the user for an observation the user is following when the muted user adds" do
        let(:o) { Observation.make! }
        before do
          Subscription.make!( user: user, resource: o )
        end
        it "a comment" do
          c = Comment.make!( user: muted_user, parent: o )
          Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
          update_action = UpdateAction.where( resource: o, notifier: c ).first
          expect( update_action ).not_to be_blank
        expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
        end
        it "an identification" do
          i = Identification.make!( user: muted_user, observation: o )
          Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
          update_action = UpdateAction.where( resource: o, notifier: i ).first
          expect( update_action ).not_to be_blank
          expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
        end
        it "an observation field value" do
          ofv = ObservationFieldValue.make!( user: muted_user, observation: o )
          Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
          update_action = UpdateAction.where( resource: o, notifier: ofv ).first
          expect( update_action ).not_to be_blank
          expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
        end
      end
      describe "notifications for the user for an observation the user created when the muted user updates" do
        let(:o) { Observation.make!( user: user ) }
        it "an observation field value" do
          ofv = after_delayed_job_finishes( ignore_run_at: true ) do
            ObservationFieldValue.make!( user: muted_user, observation: o )
          end
          update_action = UpdateAction.where( resource: o, notifier: ofv ).first
          expect( update_action ).not_to be_blank
          expect( UpdateAction.unviewed_by_user_from_query( user.id, { } ) ).to eq false
          after_delayed_job_finishes( ignore_run_at: true ) do
            ofv.update( updater: ofv.user, value: "#{ofv.value} foo" )
          end
          update_action = UpdateAction.where( resource: o, notifier: ofv ).first
          expect( update_action ).not_to be_blank
          expect( UpdateAction.unviewed_by_user_from_query( user.id, { } ) ).to eq false
        end
      end
      describe "notifications for the user from the user's observation when the muted user adds" do
        let(:o) { Observation.make!( user: user ) }
        it "an observation field value" do
          ofv = ObservationFieldValue.make!( user: muted_user, observation: o )
          Delayed::Job.all.each{ |j| Delayed::Worker.new.run( j ) }
          update_action = UpdateAction.where( resource: o, notifier: ofv ).first
          expect( update_action ).not_to be_blank
          expect( UpdateAction.unviewed_by_user_from_query( user.id, { }) ).to eq false
        end
      end
    end
  end
end
