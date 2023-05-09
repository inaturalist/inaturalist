require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a PhotosController" do
  let(:user) do
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
      put :update, format: :json, params: { id: photo.id, photo: { } }
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
end

describe PhotosController, "oauth authentication" do
  let(:token) {
    double acceptable?: true,
    accessible?: true,
    resource_owner_id: user.id,
    application: OauthApplication.make!
  }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a PhotosController"
end
