# frozen_string_literal: true

require "spec_helper"

describe ModeratorActionsController do
  let( :generic_reason ) { Faker::Lorem.sentence }

  describe "create" do
    it "creates moderator actions for photo with json format" do
      user = make_admin
      sign_in user
      photo = Photo.make!
      post :create, format: :json, params: { moderator_action: {
        resource_type: "Photo",
        resource_id: photo.id,
        reason: generic_reason,
        action: ModeratorAction::HIDE,
        private: true
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["resource_type"] ).to eq "Photo"
      expect( json["resource_id"] ).to eq photo.id
      expect( json["reason"] ).to eq generic_reason
      expect( json["action"] ).to eq ModeratorAction::HIDE
      expect( json["private"] ).to eq true
      expect( json["user_id"] ).to eq user.id
    end

    it "creates moderator actions for sound with html format" do
      user = make_admin
      sign_in user
      sound = Sound.make!
      post :create, format: :html, params: { moderator_action: {
        resource_type: "Sound",
        resource_id: sound.id,
        reason: generic_reason,
        action: ModeratorAction::UNHIDE,
        private: false
      } }
      expect( ModeratorAction.where( "resource_id = #{sound.id}" ).count ).to eq( 1 )
      expect( response ).to redirect_to( sound )
    end
  end

  let( :suspended_user ) { User.make! }
  let!( :suspend_action ) do
    ma = ModeratorAction.new(
      resource: suspended_user,
      action: ModeratorAction::SUSPEND,
      reason: generic_reason
    )
    ma.user = make_curator
    ma.save!
    ma
  end

  describe "edit" do
    it "renders for admin" do
      sign_in make_admin
      get :edit, params: { id: suspend_action.id }
      expect( response ).to be_successful
    end

    it "renders for the curator who created the action" do
      sign_in suspend_action.user
      get :edit, params: { id: suspend_action.id }
      expect( response ).to be_successful
    end

    it "redirects for a different curator" do
      sign_in make_curator
      get :edit, params: { id: suspend_action.id }
      expect( response ).to redirect_to( root_url )
    end

    it "redirects for a signed-in regular user" do
      sign_in User.make!
      get :edit, params: { id: suspend_action.id }
      expect( response ).to redirect_to( root_url )
    end

    it "does not allow editing non-SUSPEND actions" do
      admin = make_admin
      sign_in admin
      hide_action = ModeratorAction.new(
        resource: Comment.make!,
        action: ModeratorAction::HIDE,
        reason: generic_reason
      )
      hide_action.user = admin
      hide_action.save!
      get :edit, params: { id: hide_action.id }
      expect( response ).to redirect_to( root_url )
    end
  end

  describe "update" do
    let( :audit_comment_text ) { "Editing suspension: #{Faker::Lorem.sentence}" }

    it "saves audit_comment and preserves the original reason" do
      sign_in suspend_action.user
      original_reason = suspend_action.reason
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: { audit_comment: audit_comment_text }
      }
      suspend_action.reload
      expect( suspend_action.reason ).to eq original_reason
      audit = suspend_action.audits.where( action: "update" ).last
      expect( audit ).not_to be_nil
      expect( audit.comment ).to eq audit_comment_text
    end

    it "requires audit_comment when updating" do
      sign_in suspend_action.user
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: { suspended_until: 30.days.from_now }
      }
      expect( response.status ).to eq 422
      suspend_action.reload
      expect( suspend_action.audits.where( action: "update" ).count ).to eq 0
    end

    it "updates suspended_until" do
      sign_in suspend_action.user
      new_date = 30.days.from_now
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: {
          audit_comment: audit_comment_text,
          suspended_until: new_date
        }
      }
      suspend_action.reload
      expect( suspend_action.suspended_until ).to be_within( 1.second ).of( new_date )
    end

    it "sets last_edited_by_user to the current user" do
      editor = make_admin
      sign_in editor
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: { audit_comment: audit_comment_text }
      }
      suspend_action.reload
      expect( suspend_action.last_edited_by_user ).to eq editor
    end

    it "syncs suspended_until to the suspended user" do
      sign_in suspend_action.user
      new_date = 21.days.from_now
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: {
          audit_comment: audit_comment_text,
          suspended_until: new_date
        }
      }
      suspended_user.reload
      expect( suspended_user.suspended_until ).to be_within( 1.second ).of( new_date )
    end

    it "does not reset the user's suspended_at" do
      sign_in suspend_action.user
      suspended_user.reload
      original_suspended_at = suspended_user.suspended_at
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: {
          audit_comment: audit_comment_text,
          suspended_until: 7.days.from_now
        }
      }
      suspended_user.reload
      expect( suspended_user.suspended_at ).to eq original_suspended_at
    end

    it "redirects to moderation page on success" do
      sign_in make_admin
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: { audit_comment: audit_comment_text }
      }
      expect( response ).to redirect_to( moderation_person_path( suspended_user ) )
    end

    it "does not allow updates from unauthorized users" do
      sign_in make_curator
      patch :update, params: {
        id: suspend_action.id,
        moderator_action: {
          audit_comment: "Unauthorized edit reason here"
        }
      }
      expect( response ).to redirect_to( root_url )
      expect( flash[:error] ).to eq I18n.t( :you_dont_have_permission_to_do_that )
      suspend_action.reload
      expect( suspend_action.audits.where( action: "update" ).count ).to eq 0
    end
  end

  shared_examples_for "resource_url" do
    let( :non_private_moderator_action ) do
      ModeratorAction.make!(
        resource: media,
        action: ModeratorAction::HIDE,
        reason: generic_reason
      )
    end
    let( :private_moderator_action ) do
      ModeratorAction.make!(
        resource: media,
        action: ModeratorAction::HIDE,
        reason: generic_reason,
        private: true,
        user: admin
      )
    end

    describe "with a public moderator action" do
      it "allows admins to generate URLs for hidden media" do
        sign_in admin
        get :resource_url, format: :json, params: { id: non_private_moderator_action.id }
        expect( response ).to be_successful
        json = JSON.parse( response.body )
        expect( json["resource_url"] ).to eq resource_url
      end

      it "allows curators to generate URLs for hidden media" do
        sign_in make_curator
        get :resource_url, format: :json, params: { id: non_private_moderator_action.id }
        expect( response ).to be_successful
        json = JSON.parse( response.body )
        expect( json["resource_url"] ).to eq resource_url
      end

      it "does not allow regular users to generate URLs for hidden media" do
        sign_in User.make!
        get :resource_url, format: :json, params: { id: non_private_moderator_action.id }
        expect( response ).not_to be_successful
        json = JSON.parse( response.body )
        expect( json["error"] ).to eq I18n.t( :only_curators_can_access_that_page )
      end
    end

    describe "with a private moderator action" do
      it "allows admins to generate URLs for private media" do
        sign_in make_admin
        get :resource_url, format: :json, params: { id: private_moderator_action.id }
        expect( response ).to be_successful
        json = JSON.parse( response.body )
        expect( json["resource_url"] ).to eq resource_url
      end

      it "does not allow curators to generate URLs for private media" do
        sign_in make_curator
        get :resource_url, format: :json, params: { id: private_moderator_action.id }
        expect( response ).not_to be_successful
        json = JSON.parse( response.body )
        expect( json["error"] ).to eq I18n.t( :only_administrators_may_access_that_page )
      end

      it "does not allow regular users to generate URLs for private media" do
        sign_in User.make!
        get :resource_url, format: :json, params: { id: private_moderator_action.id }
        expect( response ).not_to be_successful
        json = JSON.parse( response.body )
        expect( json["error"] ).to eq I18n.t( :only_administrators_may_access_that_page )
      end
    end
  end

  describe "resource_url for photo" do
    let( :admin ) { make_admin }
    let( :media ) { LocalPhoto.make! }
    let( :resource_url ) { "https://#{Faker::Internet.domain_name}/image.png" }
    before do
      allow_any_instance_of( LocalPhoto ).to receive( :presigned_url ).and_return( resource_url )
    end

    include_examples "resource_url"
  end

  describe "resource_url for LocalSound" do
    let( :admin ) { make_admin }
    let( :media ) { LocalSound.make! }
    let( :resource_url ) { "https://#{Faker::Internet.domain_name}/sound1.wav" }
    before do
      allow_any_instance_of( LocalSound ).to receive( :presigned_url ).and_return( resource_url )
    end

    include_examples "resource_url"
  end

  describe "resource_url for SoundcloudSound" do
    let( :admin ) { make_admin }
    let( :resource_url ) { "https://#{Faker::Internet.domain_name}/sound2.mp3" }
    let( :media ) { SoundcloudSound.make!( native_page_url: resource_url ) }

    include_examples "resource_url"
  end
end
