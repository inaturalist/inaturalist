# frozen_string_literal: true

require "spec_helper"

describe Users::SessionsController do
  let( :user ) { create :user }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "create" do
    it "signs in a user with valid credentials and responds with a 302 redirect" do
      post :create, params: { user: { email: user.email, password: "monkey" } }
      expect( response ).to have_http_status( :found )
      expect( controller.send( :current_user ) ).to eq user
    end

    it "signs in with a login in place of an email" do
      post :create, params: { user: { email: user.login, password: "monkey" } }
      expect( controller.send( :current_user ) ).to eq user
    end

    it "stores the warden user in the session under the key other controllers read" do
      post :create, params: { user: { email: user.email, password: "monkey" } }
      # ApplicationController#user_from_session and action caching in
      # PlacesController and TaxaController read this raw session key, so its
      # shape is part of the app's internal contract with warden
      expect( session["warden.user.user.key"] ).not_to be_blank
      expect( session["warden.user.user.key"][0] ).to eq [user.id]
    end

    it "sets the signed _inaturalist_signed_in cookie on sign in" do
      post :create, params: { user: { email: user.email, password: "monkey" } }
      expect(
        response.cookies[ApplicationController::SIGNED_IN_TRAFFIC_COOKIE_KEY]
      ).not_to be_blank
    end

    it "redirects to session[:return_to], converting encoded spaces to plus signs" do
      session[:return_to] = "/observations?q=foo%20bar"
      post :create, params: { user: { email: user.email, password: "monkey" } }
      expect( response ).to redirect_to( "/observations?q=foo+bar" )
    end

    it "does not leave a notice flash after signing in" do
      post :create, params: { user: { email: user.email, password: "monkey" } }
      expect( flash[:notice] ).to be_blank
    end

    describe "failure" do
      it "re-renders the sign in form with a 200 and the paranoid invalid message " \
        "for a bad password" do
        post :create, params: { user: { email: user.email, password: "nope" } }
        expect( response ).to have_http_status( :ok )
        expect( flash[:alert] ).to eq I18n.t( "devise.failure.invalid" )
        expect( controller.send( :current_user ) ).to be_blank
      end

      it "responds identically for a nonexistent login" do
        post :create, params: { user: { email: "nosuchuser@example.com", password: "nope" } }
        expect( response ).to have_http_status( :ok )
        expect( flash[:alert] ).to eq I18n.t( "devise.failure.invalid" )
      end

      it "shows the inactive message for a suspended user with valid credentials" do
        user.suspend!
        post :create, params: { user: { email: user.email, password: "monkey" } }
        expect( response ).to have_http_status( :found )
        expect( flash[:alert] ).to include(
          I18n.t( "devise.failure.user.suspended" )
        )
        expect( session["warden.user.user.key"] ).to be_blank
      end

      it "locks the account after the maximum number of failed attempts " \
        "without changing the paranoid message" do
        user.update( failed_attempts: Devise.maximum_attempts - 1 )
        post :create, params: { user: { email: user.email, password: "nope" } }
        expect( user.reload.access_locked? ).to be true
        expect( flash[:alert] ).to eq I18n.t( "devise.failure.invalid" )
      end
    end

    describe "legacy authentication" do
      let( :legacy_password ) { "seekritOldPassword" }
      let( :pepper ) { "legacy-pepper" }

      before do
        site = Site.default
        site.update( preferred_legacy_rest_auth_key: pepper )
        Site.default( refresh: true )
        digest = Devise::Encryptable::Encryptors::RestfulAuthenticationSha1.digest(
          legacy_password, 10, user.password_salt, pepper
        )
        user.update_columns( encrypted_password: digest )
      end

      after do
        Site.default.update( preferred_legacy_rest_auth_key: nil )
        Site.default( refresh: true )
      end

      it "signs in a user whose password was hashed with restful_authentication SHA1" do
        post :create, params: { user: { email: user.email, password: legacy_password } }
        expect( controller.send( :current_user ) ).to eq user
        expect( response ).to have_http_status( :found )
      end
    end

    it "responds with a 404 for JSON sign in" do
      # Users::SessionsController#create only responds to HTML, and
      # ApplicationController rescues the resulting UnknownFormat with a 404.
      # API clients authenticate with OAuth or JWTs, not this endpoint, and
      # that should not change accidentally, e.g. by a change to devise's
      # navigational formats
      post :create, format: :json, params: { user: { email: user.email, password: "monkey" } }
      expect( response ).to have_http_status( :not_found )
    end
  end

  describe "destroy" do
    before do
      sign_in user
    end

    it "signs out and redirects with a 302" do
      delete :destroy
      expect( response ).to have_http_status( :found )
      expect( controller.send( :current_user ) ).to be_blank
    end

    it "clears the signed _inaturalist_signed_in cookie" do
      request.cookies[ApplicationController::SIGNED_IN_TRAFFIC_COOKIE_KEY] = "anything"
      delete :destroy
      expect(
        response.cookies.fetch( ApplicationController::SIGNED_IN_TRAFFIC_COOKIE_KEY, nil )
      ).to be_blank
    end

    it "does not leave a notice flash after signing out" do
      delete :destroy
      expect( flash[:notice] ).to be_blank
    end
  end
end
