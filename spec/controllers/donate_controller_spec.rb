require "#{File.dirname( __FILE__ )}/../spec_helper"

describe DonateController do
  describe "index" do
    let( :non_default_site ) { Site.make! }
    it "redirects with utm params when there is no utm_source param" do
      get :index
      expect( response.response_code ).to eq 302
      expect( response ).to be_redirect
      redirect_uri = URI.parse( response.location )
      redirect_params = CGI::parse( redirect_uri.query )
      expect( redirect_uri.path ).to eq "/donate"
      expect( redirect_params["utm_source"].first ).to eq Site.default.domain
      expect( redirect_params["utm_medium"].first ).to eq "web"
      expect( redirect_params["redirect"].first.yesish? ).to be true
    end

    it "redirects to the default domain" do
      get :index, params: { inat_site_id: non_default_site.id }
      expect( response.response_code ).to eq 302
      expect( response ).to be_redirect
      redirect_uri = URI.parse( response.location )
      redirect_params = CGI::parse( redirect_uri.query )
      expect( redirect_uri.path ).to eq "/donate"
      expect( redirect_params["utm_source"].first ).to eq non_default_site.domain
      expect( redirect_params["utm_medium"] ).to be_empty
      expect( redirect_params["redirect"].first.yesish? ).to be true
    end

    it "maintains utm_medium param on domain redirect" do
      utm_medium = "custom"
      get :index, params: { inat_site_id: non_default_site.id, utm_medium: utm_medium }
      expect( response.response_code ).to eq 302
      expect( response ).to be_redirect
      redirect_uri = URI.parse( response.location )
      redirect_params = CGI::parse( redirect_uri.query )
      expect( redirect_uri.path ).to eq "/donate"
      expect( redirect_params["utm_medium"].first ).to eq utm_medium
    end

    it "does not redirect if there is a utm_source param" do
      get :index, params: { utm_source: "inaturalist.org" }
      expect( response.response_code ).to eq 200
      expect( response ).to_not be_redirect
    end

    it "does not redirect if there is a redirect param" do
      get :index, params: { redirect: true }
      expect( response.response_code ).to eq 200
      expect( response ).to_not be_redirect
    end
  end

  describe "monthly_supporters" do
    let( :non_default_site ) { Site.make! }
    it "redirects with utm params when there is no utm_source param" do
      get :monthly_supporters
      expect( response.response_code ).to eq 302
      expect( response ).to be_redirect
      redirect_uri = URI.parse( response.location )
      redirect_params = CGI::parse( redirect_uri.query )
      expect( redirect_uri.path ).to eq "/monthly-supporters"
      expect( redirect_params["utm_source"].first ).to eq Site.default.domain
      expect( redirect_params["utm_medium"].first ).to eq "web"
      expect( redirect_params["redirect"].first.yesish? ).to be true
    end

    it "redirects to the default domain" do
      get :monthly_supporters, params: { inat_site_id: non_default_site.id }
      expect( response.response_code ).to eq 302
      expect( response ).to be_redirect
      redirect_uri = URI.parse( response.location )
      redirect_params = CGI::parse( redirect_uri.query )
      expect( redirect_uri.path ).to eq "/monthly-supporters"
      expect( redirect_params["utm_source"].first ).to eq non_default_site.domain
      expect( redirect_params["utm_medium"] ).to be_empty
      expect( redirect_params["redirect"].first.yesish? ).to be true
    end

    it "maintains utm_medium param on domain redirect" do
      utm_medium = "custom"
      get :monthly_supporters, params: { inat_site_id: non_default_site.id, utm_medium: utm_medium }
      expect( response.response_code ).to eq 302
      expect( response ).to be_redirect
      redirect_uri = URI.parse( response.location )
      redirect_params = CGI::parse( redirect_uri.query )
      expect( redirect_uri.path ).to eq "/monthly-supporters"
      expect( redirect_params["utm_medium"].first ).to eq utm_medium
    end

    it "does not redirect if there is a utm_source param" do
      get :monthly_supporters, params: { utm_source: "inaturalist.org" }
      expect( response.response_code ).to eq 200
      expect( response ).to_not be_redirect
    end

    it "does not redirect if there is a redirect param" do
      get :monthly_supporters, params: { redirect: true }
      expect( response.response_code ).to eq 200
      expect( response ).to_not be_redirect
    end
  end

end
