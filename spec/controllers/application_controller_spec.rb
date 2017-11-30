require 'spec_helper'

describe ApplicationController do

  describe "UnknownFormat" do
    # testing a feature implemented in the ApplicationController by using
    # the ObservationsController since there are no testable public-facing
    # actions in the ApplicationController
    describe ObservationsController do
      render_views
      before(:all) { Observation.destroy_all }
      before(:each) { enable_elastic_indexing( Observation ) }
      after(:each) { disable_elastic_indexing( Observation ) }

      it "render the 404 page for unknown formats" do
        get :index, format: :html
        expect(response.response_code).to eq 200
        expect(response.body).to include "Observations"
        get :index, format: :json
        expect(response.response_code).to eq 200
        expect(JSON.parse response.body).to eq [ ]
        get :index, format: :nonsense
        expect(response.response_code).to eq 404
        expect(response.body).to include "Sorry, that doesn't exist!"
      end
    end
  end

  describe "set_locale" do
    it "should set the session locale" do
      session[:locale] = "en"
      get :set_locale, locale: :fr
      expect( session[:locale] ).to eq "fr"
    end

    it "should do nothing for unknown locales" do
      session[:locale] = "en"
      get :set_locale, locale: :xx
      expect( session[:locale] ).to eq "en"
    end

    it "should update logged in users' locales" do
      u = User.make!(locale: "en")
      http_login(u)
      get :set_locale, locale: :fr
      u.reload
      expect( session[:locale] ).to eq "fr"
      expect( u.locale ).to eq "fr"
    end
  end

  describe WelcomeController do
    describe "check_user_last_active" do
      it "re-activate inactive users" do
        user = User.make!(last_active: nil, subscriptions_suspended_at: Time.now)
        expect( user.last_active ).to be_nil
        expect( user.subscriptions_suspended_at ).to_not be_nil
        http_login(user)
        get :index
        user.reload
        # user's last_active date is set
        expect( user.last_active ).to_not be_nil
        # subscriptions are unsuspended
        expect( user.subscriptions_suspended_at ).to be_nil
      end
    end

    describe "draft sites" do
      let(:site) { Site.make!(draft: true) }
      let(:basic_user) { User.make! }
      let(:admin_user) { make_admin }
      let(:site_admin_user) {
        u = User.make!
        SiteAdmin.create(site: site, user: u)
        u
      }

      it "does not redirect users on the main site" do
        get :index
        expect(response.response_code).to eq 200
        expect(response).to_not be_redirect
      end

      it "redirects logged-out users to log in" do
        get :index, inat_site_id: site.id
        expect(response.response_code).to eq 302
        expect(response).to be_redirect
        expect(response).to redirect_to(new_user_session_url)
      end

      it "redirects basic users to log in" do
        http_login(basic_user)
        get :index, inat_site_id: site.id
        expect(response.response_code).to eq 302
        expect(response).to be_redirect
        expect(response).to redirect_to(login_url)
      end

      it "does not redirect admins" do
        http_login(admin_user)
        get :index, inat_site_id: site.id
        expect(response.response_code).to eq 200
        expect(response).to_not be_redirect
      end

      it "does not redirect site admins" do
        http_login(site_admin_user)
        get :index, inat_site_id: site.id
        expect(response.response_code).to eq 200
        expect(response).to_not be_redirect
      end
    end

  end

end
