# frozen_string_literal: true

require "spec_helper"

describe SoundsController do
  describe "create" do
    let( :user ) { User.make! }
    let( :file ) { fixture_file_upload( "pika.mp3", "audio/mpeg" ) }
    before { sign_in user }

    it "creates sounds" do
      expect do
        post :create, format: :json, params: {
          file: file
        }
      end.to change( Sound, :count ).by( 1 )
      expect( response ).to be_successful
    end

    it "does not duplicate sounds with the same uuid" do
      uuid = SecureRandom.uuid
      LocalSound.make!( user: user, uuid: uuid )
      expect do
        post :create, format: :json, params: {
          file: file, uuid: uuid
        }
      end.not_to change( Sound, :count )
      expect( response ).to be_successful
    end

    it "does not allow sounds to be created with the same uuid by different users" do
      uuid = SecureRandom.uuid
      LocalSound.make!( user: User.make!, uuid: uuid )
      expect do
        post :create, format: :json, params: {
          file: file, uuid: uuid
        }
      end.not_to change( Sound, :count )
      expect( response ).not_to be_successful
      json = JSON.parse( response.body )
      expect( json["errors"]["uuid"] ).to eq ["has already been taken"]
    end
  end
end
