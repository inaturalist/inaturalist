# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "an ObservationSoundsController" do
  describe "create" do
    let( :file ) { fixture_file_upload( "pika.mp3", "audio/mpeg" ) }
    it "should work" do
      expect do
        post :create, format: :json, params: {
          observation_sound: { observation_id: observation.id }, file: file
        }
      end.to change( ObservationSound, :count ).by( 1 )
      expect( response ).to be_successful
    end
  end
end

describe ObservationSoundsController, "oauth authentication" do
  elastic_models( Observation )
  let( :user ) { User.make! }
  let( :token ) { double acceptable?: true, accessible?: true, resource_owner_id: user.id }
  let( :observation ) { Observation.make!( user: user ) }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive( :doorkeeper_token ) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "an ObservationSoundsController"
end

describe ObservationSoundsController, "with authentication" do
  elastic_models( Observation )
  let( :user ) { User.make! }
  let( :observation ) { Observation.make!( user: user ) }
  before do
    sign_in user
  end
  it_behaves_like "an ObservationSoundsController"
end
