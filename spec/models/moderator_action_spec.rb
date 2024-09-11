# frozen_string_literal: true

require "spec_helper"

describe ModeratorAction do
  it { is_expected.to belong_to( :user ).inverse_of :moderator_actions }
  it { is_expected.to belong_to( :resource ).inverse_of :moderator_actions }

  it { is_expected.to validate_inclusion_of( :action ).in_array ModeratorAction::ACTIONS }
  it { is_expected.to validate_length_of( :reason ).is_at_least 10 }

  describe "create" do
    describe "HIDE" do
      it "should be possible for a comment" do
        expect(
          create( :moderator_action, action: ModeratorAction::HIDE, resource: create( :comment ) )
        ).to be_persisted
      end
      it "should not be possible for a user" do
        expect(
          build( :moderator_action, action: ModeratorAction::HIDE, resource: create( :user ) )
        ).not_to be_valid
      end
    end

    describe "UNHIDE" do
      it "admins can unhide" do
        u = make_admin
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: u,
          reason: "reason for hiding" )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: u, reason: "reson for unhiding" )
        comment.reload
        expect( comment.hidden? ).to be false
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be false
      end

      it "normal users cannot unhide" do
        u = make_admin
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: u,
          reason: "reason for hiding" )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: User.make!, reason: "reson for unhiding" )
        comment.reload
        expect( comment.hidden? ).to be true
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be true
      end

      it "curators who hid the content can unhide" do
        u = make_curator
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: u,
          reason: "reason for hiding" )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: u, reason: "reson for unhiding" )
        comment.reload
        expect( comment.hidden? ).to be false
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be false
      end

      it "curators who didnt hide the content cannot unhide" do
        u = make_curator
        comment = Comment.make!
        ModeratorAction.create( action: ModeratorAction::HIDE, resource: comment, user: u,
          reason: "reason for hiding" )
        comment.reload
        expect( comment.hidden? ).to be true
        unhide_action = ModeratorAction.create( action: ModeratorAction::UNHIDE, resource: comment,
          user: make_curator, reason: "reson for unhiding" )
        comment.reload
        expect( comment.hidden? ).to be true
        expect( unhide_action.errors.any? do | e |
          e.message == "Only staff and curators who hide content can unhide it"
        end ).to be true
      end
    end

    describe "SUSPEND" do
      it "should not be possible for a comment" do
        expect(
          build( :moderator_action, action: ModeratorAction::SUSPEND, resource: create( :comment ) )
        ).not_to be_valid
      end
      it "should be possible for a user" do
        expect(
          create( :moderator_action, action: ModeratorAction::SUSPEND, resource: create( :user ) )
        ).to be_persisted
      end
      it "should suspend a user" do
        u = create :user
        expect( u ).not_to be_suspended
        create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        u.reload
        expect( u ).to be_suspended
      end
      it "should not suspend staff" do
        u = create :user, :as_admin
        expect( u ).not_to be_suspended
        expect( build( :moderator_action, action: ModeratorAction::SUSPEND, resource: u ) ).not_to be_valid
        u.reload
        expect( u ).not_to be_suspended
      end
      it "sets suspended_by_user" do
        u = create :user
        expect( u ).not_to be_suspended
        ma = create( :moderator_action, action: ModeratorAction::SUSPEND, resource: u )
        u.reload
        expect( u.suspended_by_user ).to eq ma.user
      end
    end
    describe "UNSUSPEND" do
      it "should unsuspend a user" do
        u = create :user
        u.suspend!
        expect( u ).to be_suspended
        create( :moderator_action, action: ModeratorAction::UNSUSPEND, resource: u )
        u.reload
        expect( u ).not_to be_suspended
      end
    end
  end
end
