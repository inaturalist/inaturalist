require 'spec_helper'

describe ApplicationController do

  describe "UnknownFormat" do
    # I'm testing a feature implemented in the ApplicationController by using
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
        get :index, format: :mobile
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

end
