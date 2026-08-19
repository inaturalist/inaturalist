# frozen_string_literal: true

require "spec_helper"

# Pins the behavior of failed and token-based authentication through the real
# warden middleware and Devise::FailureApp, i.e. what web users, the mobile
# apps, and other API consumers actually see. Controller specs can't cover
# this because Devise::Test::ControllerHelpers stubs warden
describe "Authentication", type: :request do
  let( :user ) { create :user }

  describe "unauthenticated HTML request to a protected page" do
    it "redirects 302 to the sign in page" do
      get "/users/edit"
      # 302 here is devise 4.9's redirect_status, which must remain :found
      expect( response ).to have_http_status( :found )
      expect( URI.parse( response.headers["Location"] ).path ).to eq new_user_session_path
    end

    it "sets the unauthenticated alert flash" do
      get "/users/edit"
      follow_redirect!
      expect( flash[:alert] ).to eq I18n.t( "devise.failure.unauthenticated" )
    end
  end

  describe "unauthenticated JSON request (API clients)" do
    it "responds 401 with the devise error body" do
      get "/users/api_token", headers: { "Accept" => "application/json" }
      expect( response ).to have_http_status( :unauthorized )
      expect( JSON.parse( response.body ) ).to eq(
        { "error" => I18n.t( "devise.failure.unauthenticated" ) }
      )
    end

    it "responds 401 for a garbage Authorization header" do
      get "/users/api_token", headers: {
        "Accept" => "application/json",
        "Authorization" => "notajwt"
      }
      expect( response ).to have_http_status( :unauthorized )
    end

    it "responds 401 for an expired JWT" do
      token = JsonWebToken.encode( { user_id: user.id }, 1.minute.ago )
      get "/users/api_token", headers: {
        "Accept" => "application/json",
        "Authorization" => token
      }
      expect( response ).to have_http_status( :unauthorized )
    end

    it "responds 401 for a valid JWT of a user that no longer exists" do
      token = JsonWebToken.encode( user_id: user.id )
      user.delete
      get "/users/api_token", headers: {
        "Accept" => "application/json",
        "Authorization" => token
      }
      expect( response ).to have_http_status( :unauthorized )
    end
  end

  describe "JWT authentication (API clients)" do
    it "returns an api token for a valid user JWT" do
      token = JsonWebToken.encode( user_id: user.id )
      get "/users/api_token", headers: {
        "Accept" => "application/json",
        "Authorization" => token
      }
      expect( response ).to have_http_status( :ok )
      expect( JSON.parse( response.body )["api_token"] ).not_to be_blank
    end

    it "delivers a password reset email for a request with an application JWT" do
      # ensure the user exists before measuring deliveries
      user
      expect do
        post "/users/password", headers: {
          "Authorization" => JsonWebToken.applicationToken
        }, params: { user: { email: user.email } }
      end.to change( ActionMailer::Base.deliveries, :size ).by( 1 )
    end
  end

  describe "locale handling in authentication failures" do
    # The locale set by ApplicationController#set_request_locale carries over
    # into Devise::FailureApp, so authentication errors are localized. With
    # devise 4.8 that happens implicitly because I18n.locale persists for the
    # duration of the request; devise 4.9.4 made the FailureApp do this
    # explicitly. Either way, API clients receive localized error messages,
    # and that should not change
    it "renders the 401 error message in the requested locale" do
      get "/users/api_token", params: { locale: "es" }, headers: {
        "Accept" => "application/json"
      }
      expect( response ).to have_http_status( :unauthorized )
      expect( JSON.parse( response.body )["error"] ).to eq(
        I18n.t( "devise.failure.unauthenticated", locale: "es" )
      )
    end

    it "keeps the HTML redirect at 302 regardless of locale" do
      get "/users/edit", params: { locale: "es" }
      expect( response ).to have_http_status( :found )
      expect( URI.parse( response.headers["Location"] ).path ).to eq new_user_session_path
    end
  end
end
