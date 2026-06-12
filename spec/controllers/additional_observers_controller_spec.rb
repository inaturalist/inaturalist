# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe AdditionalObserversController do
  let( :creator ) { User.make! }
  let( :observation ) { Observation.make!( user_id: creator.id ) }
  let( :other_user ) { User.make! }

  stub_elastic_index! Observation

  describe "create" do
    it "lets the creator add an additional observer" do
      sign_in( creator )
      post :create, format: :json, params: {
        observation_id: observation.id, user_id: other_user.id
      }
      expect( response.status ).to eq 200
      expect( observation.additional_observers.where( user_id: other_user.id ) ).to exist
    end

    it "lets an admin add an additional observer" do
      admin = make_admin
      sign_in( admin )
      post :create, format: :json, params: {
        observation_id: observation.id, user_id: other_user.id
      }
      expect( response.status ).to eq 200
      expect( observation.additional_observers.where( user_id: other_user.id ) ).to exist
    end

    it "resolves the user by login" do
      sign_in( creator )
      post :create, format: :json, params: {
        observation_id: observation.id, user_id: other_user.login
      }
      expect( response.status ).to eq 200
      expect( observation.additional_observers.where( user_id: other_user.id ) ).to exist
    end

    it "forbids a non-creator from adding" do
      sign_in( other_user )
      post :create, format: :json, params: {
        observation_id: observation.id, user_id: User.make!.id
      }
      expect( response.status ).to eq 403
    end

    it "404s when the observation does not exist" do
      sign_in( creator )
      post :create, format: :json, params: {
        observation_id: 0, user_id: other_user.id
      }
      expect( response.status ).to eq 404
    end

    it "422s on a duplicate" do
      sign_in( creator )
      AdditionalObserver.make!( observation_id: observation.id, user_id: other_user.id, added_by_user_id: creator.id )
      post :create, format: :json, params: {
        observation_id: observation.id, user_id: other_user.id
      }
      expect( response.status ).to eq 422
    end

    it "422s for a nonexistent user" do
      sign_in( creator )
      post :create, format: :json, params: {
        observation_id: observation.id, user_id: "nobody-here-at-all"
      }
      expect( response.status ).to eq 422
    end

    it "422s when adding the creator themselves" do
      sign_in( creator )
      post :create, format: :json, params: {
        observation_id: observation.id, user_id: creator.id
      }
      expect( response.status ).to eq 422
    end
  end

  describe "destroy" do
    it "lets the creator remove an additional observer" do
      sign_in( creator )
      AdditionalObserver.make!( observation_id: observation.id, user_id: other_user.id, added_by_user_id: creator.id )
      delete :destroy, format: :json, params: {
        observation_id: observation.id, user_id: other_user.id
      }
      expect( response.status ).to eq 200
      expect( observation.additional_observers.where( user_id: other_user.id ) ).not_to exist
    end

    it "is idempotent when the membership does not exist" do
      sign_in( creator )
      delete :destroy, format: :json, params: {
        observation_id: observation.id, user_id: other_user.id
      }
      expect( response.status ).to eq 200
    end

    it "forbids a non-creator from removing" do
      AdditionalObserver.make!( observation_id: observation.id, user_id: other_user.id, added_by_user_id: creator.id )
      sign_in( other_user )
      delete :destroy, format: :json, params: {
        observation_id: observation.id, user_id: other_user.id
      }
      expect( response.status ).to eq 403
      expect( observation.additional_observers.where( user_id: other_user.id ) ).to exist
    end
  end
end
