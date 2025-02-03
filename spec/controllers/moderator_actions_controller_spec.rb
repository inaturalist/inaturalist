# frozen_string_literal: true

require "spec_helper"

describe ModeratorActionsController do
  let( :generic_reason ) { Faker::Lorem.sentence }

  describe "create" do
    it "creates moderator actions" do
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
  end

  describe "resource_url" do
    let( :admin ) { make_admin }
    let( :photo ) { LocalPhoto.make! }
    let( :presigned_url ) { "https://#{Faker::Internet.domain_name}/image.png" }
    let( :moderator_action ) do
      ModeratorAction.make!(
        resource: photo,
        action: ModeratorAction::HIDE,
        reason: generic_reason
      )
    end
    before do
      allow_any_instance_of( LocalPhoto ).to receive( :presigned_url ).and_return( presigned_url )
    end

    it "allows admins to generate URLs for hidden media" do
      sign_in admin
      get :resource_url, format: :json, params: { id: moderator_action.id }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["resource_url"] ).to eq presigned_url
    end

    it "allows curators to generate URLs for hidden media" do
      sign_in make_curator
      get :resource_url, format: :json, params: { id: moderator_action.id }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["resource_url"] ).to eq presigned_url
    end

    it "does not allow regular users to generate URLs for hidden media" do
      sign_in User.make!
      get :resource_url, format: :json, params: { id: moderator_action.id }
      expect( response ).not_to be_successful
      json = JSON.parse( response.body )
      expect( json["error"] ).to eq I18n.t( :only_curators_can_access_that_page )
    end

    describe "private media" do
      let( :moderator_action ) do
        ModeratorAction.make!(
          resource: photo,
          action: ModeratorAction::HIDE,
          reason: generic_reason,
          private: true,
          user: admin
        )
      end

      it "allows admins to generate URLs for private media" do
        sign_in make_admin
        get :resource_url, format: :json, params: { id: moderator_action.id }
        expect( response ).to be_successful
        json = JSON.parse( response.body )
        expect( json["resource_url"] ).to eq presigned_url
      end

      it "does not allow curators to generate URLs for private media" do
        sign_in make_curator
        get :resource_url, format: :json, params: { id: moderator_action.id }
        expect( response ).not_to be_successful
        json = JSON.parse( response.body )
        expect( json["error"] ).to eq I18n.t( :only_administrators_may_access_that_page )
      end

      it "does not allow regular users to generate URLs for private media" do
        sign_in User.make!
        get :resource_url, format: :json, params: { id: moderator_action.id }
        expect( response ).not_to be_successful
        json = JSON.parse( response.body )
        expect( json["error"] ).to eq I18n.t( :only_administrators_may_access_that_page )
      end
    end
  end
end
