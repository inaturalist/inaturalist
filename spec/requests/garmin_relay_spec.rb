# frozen_string_literal: true

require "spec_helper"

describe "Garmin relay", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :user ) { User.make! }
  let( :garmin ) { GarminRelayController::GARMIN_URL }
  let( :token_path ) { "personalapitoken-service/personal-api/personal-api-key/token" }
  let( :search_path ) { "activitylist-service/activities/search/activities" }

  before do
    Flipper.enable_actor( GarminRelayController::FLAG, user )
    sign_in user
  end

  it "forwards the key exchange with its Authorization header" do
    stub = stub_request( :post, "#{garmin}/#{token_path}" ).
      with( headers: { "Authorization" => "ApiKey secret" } ).
      to_return( status: 200, body: "jwt-token", headers: { "Content-Type" => "text/plain" } )
    post "/garmin_relay/#{token_path}", headers: { "Authorization" => "ApiKey secret" }
    expect( stub ).to have_been_requested
    expect( response.status ).to eq 200
    expect( response.body ).to eq "jwt-token"
    expect( response.headers["Cache-Control"] ).to eq "no-store"
  end

  it "keeps the Garmin credential out of the request env that Logstasher reads" do
    stub_request( :post, "#{garmin}/#{token_path}" ).to_return( status: 200, body: "t" )
    post "/garmin_relay/#{token_path}", headers: { "Authorization" => "ApiKey secret" }
    expect( request.env ).not_to have_key "HTTP_AUTHORIZATION"
    expect( Logstasher.payload_from_request( request ).values ).not_to include "ApiKey secret"
  end

  it "forwards the activity search query string" do
    stub = stub_request( :get, "#{garmin}/#{search_path}?limit=20&start=0" ).
      with( headers: { "Authorization" => "Bearer tok" } ).
      to_return( status: 200, body: "[]", headers: { "Content-Type" => "application/json" } )
    get "/garmin_relay/#{search_path}?limit=20&start=0", headers: { "Authorization" => "Bearer tok" }
    expect( stub ).to have_been_requested
    expect( response.media_type ).to eq "application/json"
  end

  it "returns activity downloads byte for byte" do
    zip = "PK\x03\x04\x00\xFF".b
    stub_request( :get, "#{garmin}/download-service/files/activity/123" ).
      with( headers: { "Accept" => "application/x-zip-compressed" } ).
      to_return( status: 200, body: zip, headers: { "Content-Type" => "application/x-zip-compressed" } )
    get "/garmin_relay/download-service/files/activity/123",
      headers: { "Authorization" => "Bearer tok", "Accept" => "application/x-zip-compressed" }
    expect( response.body.b ).to eq zip
  end

  it "passes Garmin errors through" do
    stub_request( :post, "#{garmin}/#{token_path}" ).
      to_return( status: 429, body: "", headers: { "Retry-After" => "60" } )
    post "/garmin_relay/#{token_path}", headers: { "Authorization" => "ApiKey secret" }
    expect( response.status ).to eq 429
    expect( response.headers["Retry-After"] ).to eq "60"
  end

  it "returns 502 when Garmin is unreachable" do
    stub_request( :post, "#{garmin}/#{token_path}" ).to_timeout
    post "/garmin_relay/#{token_path}", headers: { "Authorization" => "ApiKey secret" }
    expect( response.status ).to eq 502
  end

  it "refuses paths and methods geotrack doesn't use" do
    get "/garmin_relay/userprofile-service/userprofile"
    expect( response.status ).to eq 404
    get "/garmin_relay/#{token_path}"
    expect( response.status ).to eq 404
    get "/garmin_relay/download-service/files/activity/../../userprofile-service"
    expect( response.status ).to eq 404
    expect( a_request( :any, /connectapi\.garmin\.com/ ) ).not_to have_been_made
  end

  it "is not found when the flag is off for the user" do
    Flipper.disable( GarminRelayController::FLAG )
    post "/garmin_relay/#{token_path}", headers: { "Authorization" => "ApiKey secret" }
    expect( response.status ).to eq 404
  end

  it "requires a signed in user" do
    sign_out user
    get "/garmin_relay/#{search_path}"
    expect( response.status ).to eq 302
    expect( a_request( :any, /connectapi\.garmin\.com/ ) ).not_to have_been_made
  end
end
