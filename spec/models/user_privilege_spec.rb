# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

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
      expect( UserPrivilege.earned_speech?( user ) ).to be false
      3.times do
        Identification.make!( user: user )
      end
      user.reload
      expect( UserPrivilege.earned_speech?( user ) ).to be true
    end
    it "should still be true even if the privilege was revoked" do
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
        expect( user ).not_to be_privileged_with( UserPrivilege::ORGANIZER )
        allow( UserPrivilege ).to receive( :earned_organizer? ) { true }
        make_research_grade_candidate_observation( user: user )
        Delayed::Job.find_each( &:invoke_job )
        user.reload
        expect( user ).to be_privileged_with( UserPrivilege::ORGANIZER )
      end
    end
    describe "for identification" do
      it "should earn speech after 3 identifications for others" do
        expect( user ).not_to be_privileged_with( :speech )
        3.times do
          Identification.make!( user: user )
        end
        Delayed::Job.find_each( &:invoke_job )
        expect( user ).to be_privileged_with( :speech )
      end
    end
  end

  describe "requires_privilege" do
    # This might belong in the message spec
    # describe "for message" do
    #   it "should allow creation with speech" do
    #     up = UserPrivilege.make!( privilege: UserPrivilege::SPEECH, user: user )
    #     m = Message.make( user: user, from_user: user )
    #     expect( m ).to be_valid
    #   end
    #   it "should disallow creation without speech" do
    #     m = Message.make( user: user, from_user: user )
    #     expect( m ).not_to be_valid
    #   end
    #   it "should allow creation without speech for replies" do
    #     existing_user = UserPrivilege.make!( privilege: UserPrivilege::SPEECH ).user
    #     m1 = Message.make!( user: user, from_user: existing_user, to_user: user )
    #     m2 = Message.make( user: user, from_user: user, to_user: m1.from_user, thread_id: m1.id )
    #     expect( m2 ).to be_valid
    #   end
    # end
  end
end
