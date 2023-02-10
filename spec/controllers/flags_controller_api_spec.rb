# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe FlagsController do
  let( :user ) { User.make! }
  let( :token ) do
    double acceptable?: true, accessible?: true, resource_owner_id: user.id, application: OauthApplication.make!
  end
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive( :doorkeeper_token ) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }

  describe "create" do
    let( :comment ) { Comment.make! }
    it "should add a flag" do
      expect( comment.flags.size ).to eq 0
      post :create, format: :json, params: {
        flag: { flaggable_type: "Comment", flaggable_id: comment.id, flag: Flag::SPAM }
      }
      expect( response.status ).to eq 200
      comment.reload
      expect( comment.flags.size ).to eq 1
    end
    it "should return JSON" do
      post :create, format: :json, params: {
        flag: { flaggable_type: "Comment", flaggable_id: comment.id, flag: Flag::SPAM }
      }
      json = JSON.parse( response.body )
      expect( json["id"] ).to eq comment.flags.last.id
    end
    it "should make associated observation casual when flagging a sound as a copyright infringement" do
      obs = Observation.make!( latitude: 1, longitude: 1, observed_on_string: "2020-01-09" )
      obs_sound = ObservationSound.make!( observation: obs, sound: Sound.make!( user: obs.user ) )
      obs.reload
      expect( obs ).to be_verifiable
      post :create, format: :json, params: { flag: {
        flaggable_type: "Sound",
        flaggable_id: obs_sound.sound_id,
        flag: Flag::COPYRIGHT_INFRINGEMENT
      } }
      Delayed::Worker.new.work_off
      obs_sound.reload
      expect( obs_sound.sound ).to be_flagged
      obs.reload
      expect( obs ).not_to be_verifiable
    end
  end

  describe "update" do
    let( :flag ) { Flag.make!( user: user ) }
    it "should update a flag" do
      expect( flag ).not_to be_resolved
      put :update, format: :json, params: { id: flag.id, flag: { resolved: true } }
      flag.reload
      expect( flag ).to be_resolved
    end

    it "should return JSON" do
      put :update, format: :json, params: { id: flag.id, flag: { resolved: true } }
      json = JSON.parse( response.body )
      expect( json["resolved"] ).to eq true
    end
  end

  context "when current user is flagged" do
    describe "update" do
      context "on a non taxon flag" do
        let( :flag ) { Flag.make!( user: user, flaggable: Comment.make!( user: user ) ) }
        it "should not result in an update" do
          expect( flag.flaggable_user.id ).to eq user.id
          expect( flag ).not_to be_resolved
          put :update, format: :json, params: { id: flag.id, flag: { resolved: true } }
          flag.reload
          expect( flag ).not_to be_resolved
        end
      end

      context "on a taxon flag" do
        let( :flag ) { Flag.make!( user: user, flaggable_user: user ) }
        it "should result in an update" do
          expect( flag.flaggable_user.id ).to eq user.id
          expect( flag ).not_to be_resolved
          put :update, format: :json, params: { id: flag.id, flag: { resolved: true } }
          flag.reload
          expect( flag ).to be_resolved
        end
      end
    end
  end
end
