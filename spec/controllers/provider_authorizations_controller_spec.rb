# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

OmniAuth.config.test_mode = true

describe ProviderAuthorizationsController, "create" do
  describe "for Google" do
    let( :auth_hash ) { Faker::Omniauth.google }
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new( auth_hash )
      request.env["devise.mapping"] = Devise.mappings[:user]
      request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:google]
    end
    after do
      OmniAuth.config.mock_auth[:google] = nil
    end

    it "should not store a token" do
      post :create, params: { provider: "google" }
      user = User.find_by_email( auth_hash[:info][:email] )
      google_provider_authorization = user.provider_authorizations.where( provider_name: "google_oauth2" ).first
      expect( google_provider_authorization.token ).not_to be_blank
    end

    it "should create a user" do
      expect( User.find_by_email( auth_hash[:info][:email] ) ).to be_nil
      post :create, params: { provider: "google" }
      expect( User.find_by_email( auth_hash[:info][:email] ) ).not_to be_nil
    end

    it "should confirm the user" do
      expect( User.find_by_email( auth_hash[:info][:email] ) ).to be_nil
      post :create, params: { provider: "google" }
      user = User.find_by_email( auth_hash[:info][:email] )
      expect( user ).not_to be_nil
      expect( user ).to be_confirmed
    end

    it "should set the user oauth_application_id based on return_to client_id" do
      oauth_application = OauthApplication.make!(
        trusted: true,
        redirect_uri: "https://remotesite.com/oauth_login"
      )
      session[:return_to] = oauth_application.redirect_uri + "?client_id=#{oauth_application.uid}"
      expect( User.find_by_email( auth_hash[:info][:email] ) ).to be_nil
      post :create, params: { provider: "google" }
      user = User.find_by_email( auth_hash[:info][:email] )
      expect( user ).not_to be_nil
      expect( user.oauth_application_id ).to eq oauth_application.id
    end
  end
end
