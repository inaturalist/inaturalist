# frozen_string_literal: true

require "spec_helper"

# Rack app needs route constraint; ApplicationController's admin_required filter doesn't apply.
describe "the Flipper admin UI mount", type: :request do
  include Devise::Test::IntegrationHelpers

  let( :path ) { "/admin/feature_flags" }

  # show_exceptions false in test env; route mismatch raises not 404.
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
      # Redirect keeps mount prefix; SCRIPT_NAME mishandling would break this.
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
      Flipper.enable( :client_smoke_test )
      get "#{path}/features"
      expect( response.body ).to include "client_smoke_test"
    end

    it "renders a feature detail page" do
      Flipper.enable( :client_smoke_test )
      get "#{path}/features/client_smoke_test"
      expect( response.response_code ).to eq 200
      expect( response.body ).to include "client_smoke_test"
    end

    it "explains the naming conventions in the banner" do
      get "#{path}/features"
      expect( response.body ).to include "client_"
      expect( response.body ).to include "exp_"
    end

    it "describes each flag from its prefix in the list" do
      Flipper.add( :client_smoke_test )
      Flipper.add( :exp_hello_world )
      Flipper.add( :server_smoke_test )
      get "#{path}/features"
      expect( response.body ).to include "Client-visible flag"
      expect( response.body ).to include "experiments.hello_world"
      expect( response.body ).to include "Server-only flag"
    end

    it "describes a flag on its detail page" do
      Flipper.add( :exp_hello_world )
      get "#{path}/features/exp_hello_world"
      expect( response.body ).to include "Experiment"
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

  # Rack::Protection does CSRF checking; silent failures if session doesn't reach Flipper::UI.
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
        value: "client_smoke_test",
        authenticity_token: csrf_token_from( response.body )
      }
      expect( response.response_code ).not_to eq 403
      expect( Flipper.features.map( &:key ) ).to include "client_smoke_test"
    end

    it "rejects a form post with no token" do
      get "#{path}/features/new"
      post "#{path}/features", params: { value: "client_smoke_test" }
      expect( response.response_code ).to eq 403
    end

    it "persists a percentage gate submitted through the UI" do
      Flipper.add( :client_smoke_test )
      get "#{path}/features/client_smoke_test"
      post "#{path}/features/client_smoke_test/percentage_of_actors", params: {
        value: "10",
        authenticity_token: csrf_token_from( response.body )
      }
      expect( response.response_code ).not_to eq 403
      expect( Flipper[:client_smoke_test].percentage_of_actors_value ).to eq 10
    end
  end
end
