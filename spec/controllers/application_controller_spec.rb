# frozen_string_literal: true

require "spec_helper"

describe ApplicationController do
  describe "UnknownFormat" do
    # testing a feature implemented in the ApplicationController by using
    # the ObservationsController since there are no testable public-facing
    # actions in the ApplicationController
    describe ObservationsController do
      render_views
      before( :all ) { Observation.destroy_all }
      elastic_models( Observation )

      it "render the 404 page for unknown formats" do
        get :index, format: :html
        expect( response.response_code ).to eq 200
        expect( response.body ).to include "Observations"
        get :index, format: :json
        expect( response.response_code ).to eq 200
        expect( JSON.parse( response.body ) ).to eq []
        get :index, format: :nonsense
        expect( response.response_code ).to eq 404
        expect( response.body ).to match( /doesn.*exist/ )
      end
    end
  end

  describe "set_locale" do
    it "should set the session locale" do
      session[:locale] = "en"
      get :set_locale, params: { locale: :fr }
      expect( session[:locale] ).to eq "fr"
    end

    it "should do nothing for unknown locales" do
      session[:locale] = "en"
      get :set_locale, params: { locale: :xx }
      expect( session[:locale] ).to eq "en"
    end

    it "should update logged in users' locales" do
      u = User.make!( locale: "en" )
      sign_in( u )
      get :set_locale, params: { locale: :fr }
      u.reload
      expect( session[:locale] ).to eq "fr"
      expect( u.locale ).to eq "fr"
    end
  end

  describe "ping" do
    it "returns json" do
      get :ping
      expect( response.response_code ).to eq 200
      expect( JSON.parse( response.body ) ).to eq( { "status" => "available" } )
    end
  end

  describe WelcomeController do
    describe "check_user_last_active" do
      it "re-activate inactive users" do
        user = User.make!( last_active: nil, subscriptions_suspended_at: Time.now )
        expect( user.last_active ).to be_nil
        expect( user.subscriptions_suspended_at ).to_not be_nil
        sign_in( user )
        get :index
        user.reload
        # user's last_active date is set
        expect( user.last_active ).to_not be_nil
        # subscriptions are unsuspended
        expect( user.subscriptions_suspended_at ).to be_nil
      end
    end

    describe "draft sites" do
      let( :site ) { Site.make!( draft: true ) }
      let( :basic_user ) { User.make! }
      let( :admin_user ) { make_admin }
      let( :site_admin_user ) do
        u = User.make!
        SiteAdmin.create( site: site, user: u )
        u
      end

      it "does not redirect users on the main site" do
        get :index
        expect( response.response_code ).to eq 200
        expect( response ).to_not be_redirect
      end

      it "redirects logged-out users to log in" do
        get :index, params: { inat_site_id: site.id }
        expect( response.response_code ).to eq 302
        expect( response ).to be_redirect
        expect( response ).to redirect_to( new_user_session_url )
      end

      it "redirects basic users to log in" do
        sign_in( basic_user )
        get :index, params: { inat_site_id: site.id }
        expect( response.response_code ).to eq 302
        expect( response ).to be_redirect
        expect( response ).to redirect_to( login_url )
      end

      it "does not redirect admins" do
        sign_in( admin_user )
        get :index, params: { inat_site_id: site.id }
        expect( response.response_code ).to eq 200
        expect( response ).to_not be_redirect
      end

      it "does not redirect site admins" do
        sign_in( site_admin_user )
        get :index, params: { inat_site_id: site.id }
        expect( response.response_code ).to eq 200
        expect( response ).to_not be_redirect
      end
    end
  end

  describe GuidesController do
    describe "network affiliation prompt" do
      describe "for user in partner site place" do
        let( :place ) { make_place_with_geom }
        let( :alt_site ) { Site.make!( place: place ) }
        before do
          # Stub this request to ensure the user's lat/lon is in the site place
          allow( INatAPIService ).to receive( :geoip_lookup ) {
            OpenStruct.new_recursive(
              results: {
                ll: [place.latitude, place.longitude],
                country: { name: "foo" },
                city: { name: "foo" },
                region: { name: "foo" }
              }
            )
          }
          expect( Site.default ).not_to eq alt_site
        end
        it "should be set if user views default site while not affiliated with the partner site" do
          u = User.make!( site: Site.default )
          expect( u.site ).to eq Site.default
          sign_in u
          get :index, format: :html
          expect( session[:potential_site] ).not_to be_blank
          expect( session[:potential_site][:id] ).to eq alt_site.id
        end
        it "should be set if user views default site while not affiliated with any site" do
          u = User.make!( site: nil )
          expect( u.site ).to be_nil
          sign_in u
          get :index, format: :html
          expect( session[:potential_site] ).not_to be_blank
          expect( session[:potential_site][:id] ).to eq alt_site.id
        end
        it "should not be set when viewing the site you are affiliated with" do
          u = User.make!( site: alt_site )
          expect( u.site ).to eq alt_site
          sign_in u
          get :index, format: :html, params: { inat_site_id: alt_site.id }
          expect( session[:potential_site] ).to be_blank
        end
        it "should not be set if prompting you to join the site you are affiliated with" do
          u = User.make!( site: alt_site )
          expect( u.site ).to eq alt_site
          sign_in u
          get :index, format: :html
          expect( session[:potential_site] ).to be_blank
        end
        it "should not be set when viewing a partner site" do
          third_site = Site.make!
          u = User.make!
          sign_in u
          get :index, format: :html, params: { inat_site_id: third_site.id }
          expect( session[:potential_site] ).to be_blank
        end
      end
    end
  end

  describe "allow_external_iframes" do
    describe ObservationsController do
      describe "X-FRAME-ORIGIN header" do
        it "X-FRAME-ORIGIN is set by default" do
          # the Observations#index endpoint does not call allow_external_iframes
          # and impliments the default content security policy
          get :index, format: :html
          expect( response.headers["X-Frame-Options"] ).to eq "SAMEORIGIN"
        end

        it "X-FRAME-ORIGIN is set by default" do
          # the Observations#stats endpoint calls allow_external_iframes
          get :stats, format: :html
          expect( response.headers["X-Frame-Options"] ).to eq "ALLOWALL"
        end
      end

      describe "Content-Security-Policy header" do
        it "Content-Security-Policy is set by default" do
          expect_any_instance_of( ActionDispatch::ContentSecurityPolicy ).to_not receive( :frame_ancestors )
          get :index, format: :html
          expect( request.content_security_policy.directives ).to include( "frame-ancestors" => ["'self'"])
        end

        it "Content-Security-Policy is set by default" do
          expect_any_instance_of( ActionDispatch::ContentSecurityPolicy ).to receive( :frame_ancestors ).with( nil )
          # the Observations#stats endpoint calls allow_external_iframes
          get :stats, format: :html
        end
      end
    end
  end
end
