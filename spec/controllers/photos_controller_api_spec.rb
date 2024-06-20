# frozen_string_literal: true

require "spec_helper"

shared_examples_for "a PhotosController" do
  let( :user ) do
    User.make!(
      preferred_observation_license: Observation::CC0,
      preferred_photo_license: Photo::CC_BY
    )
  end

  describe "update" do
    it "should update the license" do
      photo = LocalPhoto.make!( user: user, license: Photo::CC0 )
      put :update, format: :json, params: { id: photo.id, photo: { license: Photo::CC_BY } }
      expect( response.response_code ).to eq 200
      photo = Photo.find_by_id( photo.id )
      expect( photo.license ).to eq Photo::CC_BY
    end
    it "should update the licese by license_code" do
      photo = LocalPhoto.make!( user: user, license: Photo::CC0 )
      put :update, format: :json, params: { id: photo.id, photo: { license_code: "cc-by" } }
      expect( response.response_code ).to eq 200
      photo = Photo.find_by_id( photo.id )
      expect( photo.license ).to eq Photo::CC_BY
    end
    it "should remove a license when license_code is blank string" do
      photo = LocalPhoto.make!( user: user, license: Photo::CC0 )
      put :update, format: :json, params: { id: photo.id, photo: { license_code: "" } }
      expect( response.response_code ).to eq 200
      photo = Photo.find_by_id( photo.id )
      expect( photo.license ).to eq Photo::COPYRIGHT
    end
    it "should not remove a license when license_code is not specified" do
      photo = LocalPhoto.make!( user: user, license: Photo::CC0 )
      expect( photo.license ).to eq Photo::CC0
      put :update, format: :json, params: { id: photo.id, photo: {} }
      expect( response.response_code ).to eq 200
      photo = Photo.find_by_id( photo.id )
      expect( photo.license ).to eq Photo::CC0
    end
    it "should work with a UUID" do
      photo = LocalPhoto.make!( user: user, license: Photo::CC0 )
      put :update, format: :json, params: { id: photo.uuid, photo: { license: Photo::CC_BY } }
      expect( response.response_code ).to eq 200
      photo = Photo.find_by_id( photo.id )
      expect( photo.license ).to eq Photo::CC_BY
    end
    it "should require the owner" do
      photo = LocalPhoto.make!( user: User.make!, license: Photo::CC0 )
      put :update, format: :json, params: { id: photo.uuid, photo: { license: Photo::CC_BY } }
      expect( response.response_code ).to eq 403
      photo = Photo.find_by_id( photo.id )
      expect( photo.license ).to eq Photo::CC0
    end
  end

  describe "create" do
    let( :file ) do
      fixture_file_upload( "cuthona_abronia-tagged.jpg", "image/jpeg" )
    end

    it "creates photos" do
      expect do
        post :create, format: :json, params: {
          file: file
        }
      end.to change( Photo, :count ).by( 1 )
      expect( response ).to be_successful
    end

    it "does not duplicate photos with the same uuid" do
      uuid = SecureRandom.uuid
      LocalPhoto.make!( user: user, uuid: uuid )
      expect do
        post :create, format: :json, params: {
          file: file, uuid: uuid
        }
      end.not_to change( Photo, :count )
      expect( response ).to be_successful
    end

    it "does not allow photos to be created with the same uuid by different users" do
      uuid = SecureRandom.uuid
      LocalPhoto.make!( user: User.make!, uuid: uuid )
      expect do
        post :create, format: :json, params: {
          file: file, uuid: uuid
        }
      end.not_to change( Photo, :count )
      expect( response ).not_to be_successful
      json = JSON.parse( response.body )
      expect( json["errors"]["uuid"] ).to eq ["has already been taken"]
    end
  end
end

describe PhotosController, "oauth authentication" do
  let( :token ) do
    double acceptable?: true,
      accessible?: true,
      resource_owner_id: user.id,
      application: OauthApplication.make!
  end
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive( :doorkeeper_token ) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a PhotosController"
end
