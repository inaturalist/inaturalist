# frozen_string_literal: true

require "spec_helper"

RSpec.describe ActsAsVotable::Vote, type: :model do
  it do
    is_expected.to validate_uniqueness_of( :vote_scope ).
      scoped_to :votable_type, :votable_id, :voter_type, :voter_id
  end
end

describe ActsAsVotable::Vote do
  it "associated with proper votables" do
    u = make_user_with_privilege( UserPrivilege::INTERACTION )
    obs = Observation.make!( id: 100 )
    ident = Identification.make!( id: 100 )
    u.vote_up_for( obs )
    u.vote_up_for( ident )
    expect( obs.id ).to eq ident.id
    # first vote has an obs, not an ident, even though they have the same ID
    expect( ActsAsVotable::Vote.first.observation ).to eq obs
    expect( ActsAsVotable::Vote.first.identification ).to be_nil
    # first vote has an ident, not an obs
    expect( ActsAsVotable::Vote.last.observation ).to be_nil
    expect( ActsAsVotable::Vote.last.identification ).to eq ident
  end

  describe "exemplar identifications" do
    before do
      allow( CONFIG ).to receive( :content_creation_restriction_days ).and_return( 1 )
    end
    let( :organizer ) do
      old_organizer = User.make!( created_at: 2.days.ago )
      UserPrivilege.make!( privilege: UserPrivilege::ORGANIZER, user: old_organizer )
      old_organizer
    end
    let( :exemplar_identification ) do
      identification = Identification.make!( body: "the body" )
      identification.exemplar_identification
    end

    it "allows admins to vote" do
      vote = ActsAsVotable::Vote.create(
        votable: exemplar_identification,
        voter: make_admin
      )
      expect( vote ).to be_valid
    end

    it "allows curators to vote" do
      vote = ActsAsVotable::Vote.create(
        votable: exemplar_identification,
        voter: make_curator
      )
      expect( vote ).to be_valid
    end

    it "allows older organizers to vote" do
      vote = ActsAsVotable::Vote.create(
        votable: exemplar_identification,
        voter: organizer
      )
      expect( vote ).to be_valid
    end

    it "allows the identifier vote" do
      vote = ActsAsVotable::Vote.create(
        votable: exemplar_identification,
        voter: exemplar_identification.identification.user
      )
      expect( vote ).to be_valid
    end

    it "does not allow other users to vote" do
      vote = ActsAsVotable::Vote.create(
        votable: exemplar_identification,
        voter: User.make!
      )
      expect( vote ).not_to be_valid
    end
  end
end
