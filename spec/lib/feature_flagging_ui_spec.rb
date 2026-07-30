# frozen_string_literal: true

require "spec_helper"

# Flipper::UI is a Rack app mounted in config/routes.rb, so
# ApplicationController's admin_required filter does not apply to it -- the
# route constraint is the only thing guarding it. These specs are that guard.
describe "the Flipper admin UI mount", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :path ) { "/admin/feature_flags" }

  # show_exceptions is false in the test environment, so a route that does not
  # match raises rather than rendering a 404 page.
  describe "access" do
    it "is not routable for anonymous visitors" do
      expect { get path }.to raise_error ActionController::RoutingError
    end

    it "is not routable for signed-in non-admins" do
      sign_in User.make!
      expect { get path }.to raise_error ActionController::RoutingError
    end

    it "is not routable for curators" do
      sign_in make_curator
      expect { get path }.to raise_error ActionController::RoutingError
    end

    it "is routable for admins" do
      sign_in make_admin
      get path
      # Flipper::UI redirects its root to the feature list. The redirect keeps
      # the mount prefix, which is what would break if SCRIPT_NAME were mishandled.
      expect( response ).to redirect_to "#{path}/features"
    end

    it "renders the feature list for admins" do
      sign_in make_admin
      get "#{path}/features"
      expect( response.response_code ).to eq 200
    end
  end

  describe "for an admin" do
    before { sign_in make_admin }

    it "lists a feature that exists" do
      Flipper.enable( :flipper_smoke_test )
      get "#{path}/features"
      expect( response.body ).to include "flipper_smoke_test"
    end

    it "renders a feature detail page" do
      Flipper.enable( :flipper_smoke_test )
      get "#{path}/features/flipper_smoke_test"
      expect( response.response_code ).to eq 200
      expect( response.body ).to include "flipper_smoke_test"
    end

    it "serves its own assets" do
      get "#{path}/css/application.css"
      expect( response.response_code ).to eq 200
    end

    it "does not phone home for a version check" do
      get "#{path}/features"
      expect( response.body ).not_to include "version.js"
    end
  end

  # Flipper::UI does its own CSRF checking with Rack::Protection rather than
  # Rails' protect_from_forgery, reading and writing rack.session directly.
  # Rack::Protection swallows any error and answers 403, so if our
  # activerecord-session_store session were not reaching it, every form in the
  # admin UI would fail with no useful message. These specs are the canary.
  describe "form submission" do
    before { sign_in make_admin }

    def csrf_token_from( body )
      body[/name="authenticity_token" value="([^"]*)"/, 1]
    end

    it "renders a usable CSRF token" do
      get "#{path}/features/new"
      expect( csrf_token_from( response.body ) ).to be_present
    end

    it "accepts a form post carrying that token" do
      get "#{path}/features/new"
      post "#{path}/features", params: {
        value: "flipper_smoke_test",
        authenticity_token: csrf_token_from( response.body )
      }
      expect( response.response_code ).not_to eq 403
      expect( Flipper.features.map( &:key ) ).to include "flipper_smoke_test"
    end

    it "rejects a form post with no token" do
      get "#{path}/features/new"
      post "#{path}/features", params: { value: "flipper_smoke_test" }
      expect( response.response_code ).to eq 403
    end

    it "persists a percentage gate submitted through the UI" do
      Flipper.add( :flipper_smoke_test )
      get "#{path}/features/flipper_smoke_test"
      post "#{path}/features/flipper_smoke_test/percentage_of_actors", params: {
        value: "10",
        authenticity_token: csrf_token_from( response.body )
      }
      expect( response.response_code ).not_to eq 403
      expect( Flipper[:flipper_smoke_test].percentage_of_actors_value ).to eq 10
    end
  end
end
