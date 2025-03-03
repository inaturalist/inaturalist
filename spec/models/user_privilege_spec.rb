# frozen_string_literal: true

require "spec_helper"

describe UserPrivilege do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to( :revoke_user ).class_name "User" }

  it { is_expected.to validate_uniqueness_of( :user_id ).scoped_to :privilege }

  elastic_models( Observation )

  let( :user ) { User.make! }

  describe "speech" do
    it "should be earned when a user has 3 verifiable observations" do
      expect( UserPrivilege.earned_speech?( user ) ).to be false
      3.times do
        make_research_grade_candidate_observation( user: user )
      end
      user.reload
      expect( UserPrivilege.earned_speech?( user ) ).to be true
    end
    it "should not be earned when a user has 2 verifiable observations and 1 unverifiable" do
      expect( UserPrivilege.earned_speech?( user ) ).to be false
      make_research_grade_candidate_observation( user: user )
      Observation.make!( user: user )
      user.reload
      expect( UserPrivilege.earned_speech?( user ) ).to be false
    end
    it "should be earned when a user has 3 identifications" do
      UserPrivilege.make!( privilege: UserPrivilege::INTERACTION, user: user )
      expect( UserPrivilege.earned_speech?( user ) ).to be false
      3.times do
        Identification.make!( user: user )
      end
      user.reload
      expect( UserPrivilege.earned_speech?( user ) ).to be true
    end
    it "should still be true even if the privilege was revoked" do
      UserPrivilege.make!( privilege: UserPrivilege::INTERACTION, user: user )
      expect( UserPrivilege.earned_speech?( user ) ).to be false
      3.times do
        Identification.make!( user: user )
      end
      user.reload
      expect( UserPrivilege.earned_speech?( user ) ).to be true
      priv = UserPrivilege.create( user: user, privilege: UserPrivilege::SPEECH )
      priv.revoke!
      user.reload
      expect( UserPrivilege.earned_speech?( user ) ).to be true
    end
  end

  describe "interaction" do
    it "users with confirmed emails earn interaction" do
      expect( UserPrivilege.earned_interaction?( User.make!( confirmed_at: Time.now ) ) ).to be true
    end

    it "users without confirmed emails do not earn interaction" do
      expect( UserPrivilege.earned_interaction?( User.make!( confirmed_at: nil ) ) ).to be false
    end

    it "users without confirmed emails created before active date earn interaction" do
      expect( CONFIG ).to receive( :email_confirmation_for_interaction_active_date ).
        at_least( :once ).and_return( Date.tomorrow.to_s )
      expect( UserPrivilege.earned_interaction?( User.make!( confirmed_at: nil ) ) ).to be true
    end

    it "users without confirmed emails created after active date do not earn interaction" do
      expect( CONFIG ).to receive( :email_confirmation_for_interaction_active_date ).
        at_least( :once ).and_return( Date.yesterday.to_s )
      expect( UserPrivilege.earned_interaction?( User.make!( confirmed_at: nil ) ) ).to be false
    end
  end

  describe "earns_privilege" do
    describe "for observation" do
      it "should earn speech after 3 verifiable observations" do
        expect( user ).not_to be_privileged_with( UserPrivilege::SPEECH )
        3.times do
          make_research_grade_candidate_observation( user: user )
        end
        Delayed::Job.find_each( &:invoke_job )
        user.reload
        expect( user ).to be_privileged_with( UserPrivilege::SPEECH )
      end

      it "should not lose speech if an observation is deleted" do
        3.times do
          make_research_grade_candidate_observation( user: user )
        end
        Delayed::Job.find_each( &:invoke_job )
        user.reload
        expect( user ).to be_privileged_with( UserPrivilege::SPEECH )
        user.observations.last.destroy
        # This is lame but there are some jobs that will fail after the obs is deleted
        Delayed::Job.find_each do | j |
          j.invoke_job
        rescue StandardError
          nil
        end
        user.reload
        expect( user ).to be_privileged_with( UserPrivilege::SPEECH )
      end

      it "should earn organizer" do
        expect( UserPrivilege.earned_organizer?( user ) ).to be false
        stub_verifiable_obs = double( "verifiable" )
        expect( stub_verifiable_obs ).to receive( :limit ).and_return( ( 1..50 ).to_a )
        expect( user.observations ).to receive( :verifiable ).and_return( stub_verifiable_obs )
        expect( UserPrivilege.earned_organizer?( user ) ).to be true
      end

      it "should not earn organizer if email is not confirmed" do
        expect( UserPrivilege.earned_organizer?( user ) ).to be false
        stub_verifiable_obs = double( "verifiable" )
        expect( stub_verifiable_obs ).to receive( :limit ).and_return( ( 1..50 ).to_a )
        expect( user.observations ).to receive( :verifiable ).and_return( stub_verifiable_obs )
        expect( UserPrivilege.earned_organizer?( user ) ).to be true
        user.update( confirmed_at: nil )
        expect( UserPrivilege.earned_organizer?( user ) ).to be false
      end

      it "organizer is earned after email is confirmed" do
        user = User.make!( confirmed_at: nil )
        expect( UserPrivilege.earned_organizer?( user ) ).to be false
        stub_verifiable_obs = double( "verifiable" )
        expect( stub_verifiable_obs ).to receive( :limit ).and_return( ( 1..50 ).to_a )
        expect( user.observations ).to receive( :verifiable ).and_return( stub_verifiable_obs )
        expect( UserPrivilege.earned_organizer?( user ) ).to be false
        user.update( confirmed_at: Time.now )
        expect( UserPrivilege.earned_organizer?( user ) ).to be true
      end
    end

    describe "for identification" do
      it "should earn speech after 3 identifications for others" do
        UserPrivilege.make!( privilege: UserPrivilege::INTERACTION, user: user )
        expect( user ).not_to be_privileged_with( :speech )
        3.times do
          Identification.make!( user: user )
        end
        Delayed::Job.find_each( &:invoke_job )
        expect( user ).to be_privileged_with( :speech )
      end
    end
  end
end
