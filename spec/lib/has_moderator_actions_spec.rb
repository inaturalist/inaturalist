# frozen_string_literal: true

require "spec_helper"

describe HasModeratorActions do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  it "allows resources to have moderator actions" do
    comment = Comment.make!
    moderator_action = ModeratorAction.make!( resource: comment )
    comment.reload
    expect( comment.moderator_actions.length ).to eq 1
    expect( comment.moderator_actions.first ).to eq moderator_action
  end

  it "does not destroy moderator actions when the resource is destroyed" do
    comment = Comment.make!
    ModeratorAction.make!( resource: comment )
    comment.reload
    expect( comment.moderator_actions.length ).to eq 1
    expect( ModeratorAction.count ).to eq 1
    comment.destroy
    expect( ModeratorAction.count ).to eq 1
    expect( ModeratorAction.first.resource_type ).to eq "Comment"
    expect( ModeratorAction.first.resource_id ).to eq comment.id
    expect( ModeratorAction.first.resource ).to be_nil
  end

  describe "hidden?" do
    it "resources with HIDE moderator actions are hidden" do
      comment = Comment.make!
      expect( comment.hidden? ).to be false
      ModeratorAction.make!( resource: comment, action: ModeratorAction::HIDE )
      comment.reload
      expect( comment.hidden? ).to be true
    end

    it "users cannot be marked as hidden" do
      user = make_curator
      expect( user.hidden? ).to be false
      ModeratorAction.make!( user: user, resource: Comment.make!, action: ModeratorAction::HIDE )
      user.reload
      expect( user.hidden? ).to be false
    end
  end

  describe "moderated_as_private?" do
    it "resources with private HIDE moderator actions are moderated_as_private" do
      comment = Comment.make!
      expect( comment.hidden? ).to be false
      ModeratorAction.make!(
        resource: comment, action: ModeratorAction::HIDE, private: true, user: make_admin
      )
      comment.reload
      expect( comment.moderated_as_private? ).to be true
    end

    it "users cannot be marked as moderated_as_private" do
      user = make_admin
      expect( user.hidden? ).to be false
      ModeratorAction.make!(
        user: user, resource: Comment.make!, action: ModeratorAction::HIDE, private: true
      )
      user.reload
      expect( user.moderated_as_private? ).to be false
    end
  end

  describe "most_recent_moderator_action" do
    it "returns the most recent moderator action on non-User resources" do
      comment = Comment.make!
      expect( comment.most_recent_moderator_action ).to be nil
      _first_action = ModeratorAction.make!(
        resource: comment, action: ModeratorAction::HIDE, user: make_admin
      )
      last_action = ModeratorAction.make!(
        resource: comment, action: ModeratorAction::HIDE, private: true, user: make_admin
      )
      comment.reload
      expect( comment.most_recent_moderator_action ).to eq last_action
    end

    it "returns the most recent moderator action on Users" do
      user = make_curator
      comment = Comment.make!
      expect( comment.most_recent_moderator_action ).to be nil
      action_on_user = ModeratorAction.make!(
        resource: user, action: ModeratorAction::SUSPEND
      )
      _user_action = ModeratorAction.make!(
        resource: comment, action: ModeratorAction::HIDE, user: user
      )
      user.reload
      expect( user.most_recent_moderator_action ).to eq action_on_user
    end
  end

  describe "hideable_by?" do
    it "resources are not hideable by nil users" do
      expect( Comment.make!.hideable_by?( nil ) ).to eq false
    end

    it "users are not hideable by themselves" do
      admin = make_admin
      expect( admin.hideable_by?( admin ) ).to eq false
    end

    it "resources are not hideable by their creators" do
      admin = make_admin
      comment = Comment.make!( user: admin )
      expect( comment.hideable_by?( admin ) ).to eq false
    end

    it "resources are hideable by curators" do
      comment = Comment.make!
      curator = make_curator
      expect( comment.hideable_by?( curator ) ).to eq true
    end

    it "resources are hideable by admins" do
      comment = Comment.make!
      admin = make_admin
      expect( comment.hideable_by?( admin ) ).to eq true
    end

    it "resources are not hideable by non-curator, non-admins" do
      comment = Comment.make!
      user = User.make!
      expect( comment.hideable_by?( user ) ).to eq false
    end
  end

  describe "unhideable_by?" do
    it "resources are not unhideable by nil users" do
      expect( Comment.make!.unhideable_by?( nil ) ).to eq false
    end

    it "users are not unhideable by themselves" do
      admin = make_admin
      expect( admin.unhideable_by?( admin ) ).to eq false
    end

    it "resources are not unhideable by their creators" do
      admin = make_admin
      comment = Comment.make!( user: admin )
      expect( comment.unhideable_by?( admin ) ).to eq false
    end

    it "resources are not unhideable by curators" do
      comment = Comment.make!
      curator = make_curator
      expect( comment.unhideable_by?( curator ) ).to eq false
    end

    it "resources are unhideable by admins" do
      comment = Comment.make!
      admin = make_admin
      expect( comment.unhideable_by?( admin ) ).to eq true
    end

    it "resources are not unhideable by non-curator, non-admins" do
      comment = Comment.make!
      user = User.make!
      expect( comment.unhideable_by?( user ) ).to eq false
    end
  end

  describe "hidden_content_viewable_by?" do
    it "hidden resources are not viewable by nil users" do
      expect( Comment.make!.hidden_content_viewable_by?( nil ) ).to eq false
    end

    it "hidden users are viewable by themselves" do
      admin = make_admin
      expect( admin.hidden_content_viewable_by?( admin ) ).to eq true
    end

    it "hidden resources are viewable by their creators" do
      admin = make_admin
      comment = Comment.make!( user: admin )
      expect( comment.hidden_content_viewable_by?( admin ) ).to eq true
    end

    it "hidden resources are viewable by curators" do
      comment = Comment.make!
      curator = make_curator
      expect( comment.hidden_content_viewable_by?( curator ) ).to eq true
    end

    it "hidden resources are viewable by admins" do
      comment = Comment.make!
      admin = make_admin
      expect( comment.hidden_content_viewable_by?( admin ) ).to eq true
    end

    it "hidden resources are not viewable by non-curator, non-admins" do
      comment = Comment.make!
      user = User.make!
      expect( comment.hidden_content_viewable_by?( user ) ).to eq false
    end
  end
end
