require File.dirname(__FILE__) + '/../spec_helper'

def register_user_with_params( params = {} )
  u = User.make
  post :create, format: "json", params: { user: {
    login: u.login,
    password: "zomgbar",
    password_confirmation: "zomgbar",
    email: u.email
  }.merge( params ) }
  User.find_by_login(u.login)
end

describe Users::RegistrationsController, "create" do
  elastic_models( Observation )
  # This is mildly insane, but here we're turning on forgery protection to test
  # that we're successfully turning it off in this controller. Theoretically
  # someone who is not signed in doesn't have an active session that coulbe be
  # exploited by CSRF, and someone who is signed in should be protected by our
  # own code that will cause registration to fail when you try to create
  # another account
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    stub_request(:get, /#{INatAPIService::ENDPOINT}/).
      to_return(status: 200, body: "{ }",
        headers: { "Content-Type" => "application/json" })
  end

  it "should create a user" do
    expect {
      register_user_with_params
    }.to change(User, :count).by(1)
  end

  it "should return json about the user" do
    register_user_with_params
    expect {
      json = JSON.parse(response.body)
    }.not_to raise_error
  end

  it "should not return the password" do
    register_user_with_params
    expect( response.body ).not_to be =~ /zomgbar/
  end

  it "should show errors when invalid" do
    post :create, format: :json, params: { user: {
      password: "zomgbar",
      password_confirmation: "zomgbar"
    } }
    json = JSON.parse( response.body )
    expect( json["errors"] ).not_to be_blank
  end

  it "should return 422 when invalid" do
    post :create, format: :json, params: { user: {
      login: "zapphytest2",
      password: "zomgbar",
      password_confirmation: "zomgbar"
    } }
    expect( response.response_code ).to eq 422
  end

  it "should not have duplicate email errors when email taken" do
    existing = User.make!
    user = User.make( email: existing.email )
    post :create, format: :json, params: { user: {
      login: user.login,
      email: user.email,
      password: "zomgbar",
      password_confirmation: "zomgbar"
    } }
    json = JSON.parse( response.body )
    expect( json["errors"].uniq.size ).to eq json["errors"].size
  end

  it "should assign a user to a site" do
    @site = Site.make!( url: "test.host" ) # hoping the test host is the same across platforms...
    u = register_user_with_params
    expect( u.site ).to eq @site
  end

  it "should assign a user to a site using inat_site_id param" do
    site1 = Site.make!( url: "test.host" )
    site2 = Site.make!
    u = User.make
    post :create, params: { inat_site_id: site2.id, user: {
      login: u.login,
      password: "zomgbar",
      password_confirmation: "zomgbar",
      email: u.email
    } }
    expect( User.find_by_login( u.login ).site ).to eq site2
  end

  it "should give the user the locale of the requested site" do
    locale = "es-MX"
    site = Site.make!( url: "test.host", preferred_locale: locale )
    u = register_user_with_params
    expect( u.locale ).to eq site.preferred_locale
  end

  it "should give the user the locale of the site specified by inat_site_id" do
    locale = "es-MX"
    site1 = Site.make!( url: "test.host" )
    site2 = Site.make!( preferred_locale: locale )
    u = User.make
    post :create, params: { inat_site_id: site2.id, user: {
      login: u.login,
      password: "zomgbar",
      password_confirmation: "zomgbar",
      email: u.email
    } }
    expect( User.find_by_login( u.login ).locale ).to eq locale
  end

  it "should accept time_zone" do
    u = register_user_with_params( time_zone: "America/Los_Angeles" )
    expect( u.time_zone ).to eq "America/Los_Angeles"
  end

  it "should accept preferred_photo_license" do
    u = register_user_with_params( preferred_photo_license: Observation::CC_BY )
    expect( u.preferred_photo_license ).to eq Observation::CC_BY
  end

  it "should handle formatting mixups in license" do
    u = register_user_with_params(
      preferred_observation_license: "CC-BY_NC",
      preferred_photo_license: "CC_BY_NC",
      preferred_sound_license: "CC^by$NC"
    )
    new_u = User.where( login: u.login ).first
    expect( new_u.preferred_photo_license ).to eq Observation::CC_BY_NC
    expect( new_u.preferred_sound_license ).to eq Observation::CC_BY_NC
    expect( new_u.preferred_observation_license ).to eq Observation::CC_BY_NC
  end

  it "should create a user with a blank time_zone" do
    expect {
      register_user_with_params( time_zone: "" )
    }.to change( User, :count ).by( 1 )
  end

  it "should default to an oauth_application_id of zero" do
    u = register_user_with_params
    expect( u.oauth_application_id ).to eq 0
  end

  it "should set the oauth_application_id based on the Seek User-Agent" do
    a = OauthApplication.make!( name: "Seek" )
    request.env["HTTP_USER_AGENT"] = "Seek/2.12.9 Handset (Build 199) Android/8.1.0"
    u = register_user_with_params
    expect( u.oauth_application_id ).to eq a.id
  end

  it "should set the oauth_application_id based on the iPhone User-Agent" do
    a = OauthApplication.make!( name: "iNaturalist iPhone App" )
    request.env["HTTP_USER_AGENT"] = "iNaturalist/636 CFNetwork/1220.1 Darwin/20.3.0"
    u = register_user_with_params
    expect( u.oauth_application_id ).to eq a.id
  end

  it "should set the oauth_application_id based on the Seek User-Agent" do
    a = OauthApplication.make!( name: "iNaturalist Android App" )
    request.env["HTTP_USER_AGENT"] = "iNaturalist/1.23.4 (Build 493; Android 4.14.190-20973144-abA715WVLU2CUB5 A715WVLU2CUB5; SDK 30; a71 SM-A715W a71cs; OS Version 11)"
    u = register_user_with_params
    expect( u.oauth_application_id ).to eq a.id
  end

  it "should not allow an authenticated user to create another user" do
    sign_in( create( :user ) )
    expect do
      register_user_with_params
    end.not_to change( User, :count )
    expect( response.response_code ).to eq 422
  end

  it "should accept data_transfer_consent" do
    u = register_user_with_params( data_transfer_consent: true )
    expect( u.data_transfer_consent_at ).not_to be_blank
  end

  it "should accept pi_consent" do
    u = register_user_with_params( pi_consent: true )
    expect( u.pi_consent_at ).not_to be_blank
  end
end
