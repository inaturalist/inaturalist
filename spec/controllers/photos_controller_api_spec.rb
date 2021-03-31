require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a PhotosController" do
  let(:user) { User.make! }

  describe "update" do
    it "should update the license" do
      photo = LocalPhoto.make!( user: user, license: Photo::CC0 )
      put :update, format: :json, id: photo.id, photo: { license: Photo::CC_BY }
      expect( response.response_code ).to eq 200
      photo.reload
      expect( photo.license ).to eq Photo::CC_BY
    end
    it "should work with a UUID" do
      photo = LocalPhoto.make!( user: user, license: Photo::CC0 )
      put :update, format: :json, id: photo.uuid, photo: { license: Photo::CC_BY }
      expect( response.response_code ).to eq 200
      photo.reload
      expect( photo.license ).to eq Photo::CC_BY
    end
    it "should require the owner" do
      photo = LocalPhoto.make!( user: User.make!, license: Photo::CC0 )
      put :update, format: :json, id: photo.uuid, photo: { license: Photo::CC_BY }
      expect( response.response_code ).to eq 403
      photo.reload
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
  it_behaves_like "a PhotosController"
end
