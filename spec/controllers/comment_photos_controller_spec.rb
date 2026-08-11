# frozen_string_literal: true

require "spec_helper"

describe CommentPhotosController do
  elastic_models( Observation )

  let( :user ) { make_user_with_privilege( UserPrivilege::INTERACTION ) }
  let( :token ) do
    double acceptable?: true, accessible?: true, resource_owner_id: user.id,
      application: OauthApplication.make!
  end

  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive( :doorkeeper_token ) { token }
  end

  describe "create" do
    it "creates an unlinked comment photo for the user's own photo" do
      photo = LocalPhoto.make!( user: user )
      expect do
        post :create, format: :json, params: { photo_id: photo.id }
      end.to change( CommentPhoto, :count ).by( 1 )
      expect( response.response_code ).to eq 201
      cp = CommentPhoto.last
      expect( cp.user_id ).to eq user.id
      expect( cp.photo_id ).to eq photo.id
      expect( cp.comment_id ).to be_nil
    end

    it "rejects a photo the user does not own" do
      photo = LocalPhoto.make!( user: User.make! )
      post :create, format: :json, params: { photo_id: photo.id }
      expect( response.response_code ).to eq 422
      expect( CommentPhoto.count ).to eq 0
    end

    it "422s when no photo is specified" do
      post :create, format: :json, params: {}
      expect( response.response_code ).to eq 422
    end

    it "throttles once the hourly cap is reached" do
      stub_const( "CommentPhotosController::MAX_PER_HOUR", 1 )
      first = LocalPhoto.make!( user: user )
      second = LocalPhoto.make!( user: user )
      post :create, format: :json, params: { photo_id: first.id }
      expect( response.response_code ).to eq 201
      post :create, format: :json, params: { photo_id: second.id }
      expect( response.response_code ).to eq 429
    end
  end
end
