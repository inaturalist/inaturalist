# frozen_string_literal: true

require "spec_helper"

# Specs pin response shape; mobile and Node API are built against it.
describe "GET /feature_flags", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :flag ) { :demo_banner }

  def body
    JSON.parse( response.body )
  end

  describe "the response shape" do
    it "returns flags and experiments" do
      get "/feature_flags"
      expect( response.response_code ).to eq 200
      expect( body.keys ).to match_array %w(flags experiments)
    end

    it "returns a boolean for every client flag" do
      get "/feature_flags"
      expect( body["flags"].keys ).to match_array FeatureFlagging::CLIENT_FLAGS.map( &:to_s )
      expect( body["flags"].values ).to all( be_in( [true, false] ) )
    end

    it "returns a key for every experiment, null when unenrolled" do
      get "/feature_flags"
      expect( body["experiments"].keys ).
        to match_array FeatureFlagging::KNOWN_EXPERIMENTS.keys.map( &:to_s )
      expect( body["experiments"].values ).to all( be_nil )
    end

    # Per-actor payload in shared cache would expose user A's flags to user B; correctness requirement.
    it "marks the response as privately cacheable only" do
      get "/feature_flags"
      expect( response.headers["Cache-Control"] ).to include "private"
      expect( response.headers["Cache-Control"] ).not_to include "public"
    end
  end

  describe "an anonymous caller" do
    it "gets a 200 rather than a 401" do
      get "/feature_flags"
      expect( response.response_code ).to eq 200
    end

    it "sees every flag off" do
      get "/feature_flags"
      expect( body["flags"].values ).to all( be false )
    end

    it "does not inherit another actor's gate" do
      Flipper.enable_actor( flag, User.make! )
      get "/feature_flags"
      expect( body["flags"][flag.to_s] ).to be false
    end

    it "does see a fully enabled flag" do
      Flipper.enable( flag )
      get "/feature_flags"
      expect( body["flags"][flag.to_s] ).to be true
    end
  end

  describe "a caller with a session" do
    let( :user ) { User.make! }

    before { sign_in user }

    it "resolves an actor gate" do
      Flipper.enable_actor( flag, user )
      get "/feature_flags"
      expect( body["flags"][flag.to_s] ).to be true
    end

    it "resolves a percentage gate consistently across requests" do
      Flipper.enable_percentage_of_actors( flag, 50 )
      values = 5.times.map do
        get "/feature_flags"
        body["flags"][flag.to_s]
      end
      expect( values.uniq.size ).to eq 1
    end

    it "reports an assigned variant once enrolled" do
      Flipper.enable( FeatureFlagging.experiment_flag( :hello_world ) )
      get "/feature_flags"
      expect( body["experiments"]["hello_world"] ).to be_in %w(control treatment)
    end
  end

  describe "a caller with a user JWT" do
    let( :user ) { User.make! }

    def jwt_headers( for_user )
      { "HTTP_AUTHORIZATION" => JsonWebToken.encode( user_id: for_user.id ) }
    end

    it "resolves flags for the token's user" do
      Flipper.enable_actor( flag, user )
      get "/feature_flags", headers: jwt_headers( user )
      expect( body["flags"][flag.to_s] ).to be true
    end

    it "does not resolve another user's gate" do
      Flipper.enable_actor( flag, User.make! )
      get "/feature_flags", headers: jwt_headers( user )
      expect( body["flags"][flag.to_s] ).to be false
    end
  end

  # Regression guard: application token authenticates as shared User;-1 that must not be bucketed with real actors.
  describe "a caller with an application JWT" do
    let( :app_headers ) do
      { "HTTP_AUTHORIZATION" => JsonWebToken.applicationToken }
    end

    it "is treated as anonymous, not as actor User;-1" do
      Flipper.enable_actor( flag, User.new( id: -1, login: "anonymous" ) )
      get "/feature_flags", headers: app_headers
      expect( response.response_code ).to eq 200
      expect( body["flags"][flag.to_s] ).to be false
    end

    it "is not swept into a percentage rollout" do
      Flipper.enable_percentage_of_actors( flag, 100 )
      get "/feature_flags", headers: app_headers
      expect( body["flags"][flag.to_s] ).to be false
    end

    it "is never enrolled in an experiment" do
      Flipper.enable( FeatureFlagging.experiment_flag( :hello_world ) )
      get "/feature_flags", headers: app_headers
      expect( body["experiments"]["hello_world"] ).to be_nil
    end
  end
end
