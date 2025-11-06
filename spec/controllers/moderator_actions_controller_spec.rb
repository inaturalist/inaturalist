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
