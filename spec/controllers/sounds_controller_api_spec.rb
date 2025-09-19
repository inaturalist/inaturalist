# frozen_string_literal: true

require "spec_helper"

describe SoundsController do
  let( :user ) { User.make! } 
  let( :file ) { fixture_file_upload( "pika.mp3", "audio/mpeg" ) }

  describe "show" do
    let( :sound ) { LocalSound.make!( user: user ) }

    it "for existing sound shows sound" do
      get :show, format: :html, params: {
        id: sound.id
      }
      expect(assigns(:sound)).to eq(sound)
      expect( response ).to be_successful
    end

    it "for non-existent sound returns not found" do
      get :show, format: :html, params: {
        id: (sound.id + 1)
      }
      expect( response ).to be_not_found
    end
  end

  describe "update" do
    before { sign_in user }
    let( :sound ) { LocalSound.make!( user: user) }

    describe "for existing sound" do
      it "for unpermitted field does not update those fields" do
        updated_user = User.make!
        patch :update, format: :json, params: {
          id: sound.id,
          sound: {
            user: updated_user
          }
        }
        expect( response ).to be_successful
        unchanged_sound = Sound.find_by_id( sound.id )
        expect( unchanged_sound.user ).to eq user 
        expect( unchanged_sound.user ).not_to eq updated_user 
      end

      it "for permitted field returns success" do
        sound_to_update = LocalSound.make!( user: user, license_code: Sound::CC_BY )
        updated_license = Sound::CC0
        patch :update, format: :json, params: {
          id: sound.id,
          sound: {
            license: updated_license
          }
        }
        expect( response ).to be_successful
        updated_sound = Sound.find_by_id( sound.id )
        expect( updated_sound.license ).to eq updated_license
      end
    end

    it "with different signed in user returns forbidden" do
      other_user = User.make!
      sign_in other_user
      patch :update, format: :json, params: {
        id: (sound.id)
      }
      expect( response ).to have_http_status(:forbidden)
    end
    
    it "for non-existent update returns not found" do
      patch :update, format: :json, params: {
        id: (sound.id + 1)
      }
      expect( response ).to be_not_found
    end
  end

  describe "create" do
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

  describe "hide" do
    let( :sound ) { LocalSound.make!( user: user, id: 1 ) }

    it "regular users cannot access the hide endpoint" do
      sign_in User.make!
      get :hide, params: { id: sound.id }
      expect( response ).not_to be_successful
    end

    it "curators can access the hide endpoint" do
      sign_in make_curator
      get :hide, params: { id: sound.id }
      expect( response ).to be_successful
      expect( response ).to render_template('moderator_actions/hide_content')
    end

    it "admins can access the hide endpoint" do
      sign_in make_admin
      get :hide, params: { id: sound.id }
      expect( response ).to be_successful
      expect( response ).to render_template('moderator_actions/hide_content')
    end

    it "for non-existent sound and correct role returns not found" do
      sign_in make_curator
      get :hide, params: {
        id: (sound.id + 1)
      }
      expect( response ).to be_not_found
    end
  end
end