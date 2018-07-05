require File.dirname(__FILE__) + '/../spec_helper'

describe Users::RegistrationsController, "create" do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    stub_request(:get, /#{INatAPIService::ENDPOINT}/).
      to_return(status: 200, body: "{ }",
        headers: { "Content-Type" => "application/json" })
  end

  it "should create a user" do
    u = User.make
    expect {
      post :create, :user => {:login => u.login, :password => "zomgbar", :password_confirmation => "zomgbar", :email => u.email}
    }.to change(User, :count).by(1)
  end

  it "should return json about the user" do
    u = User.make
    post :create, :format => :json, :user => {
      :login => u.login, 
      :password => "zomgbar", 
      :password_confirmation => "zomgbar", 
      :email => u.email
    }
    expect {
      json = JSON.parse(response.body)
    }.not_to raise_error
  end

  it "should not return the password" do
    u = User.make
    post :create, :format => :json, :user => {
      :login => u.login, 
      :password => "zomgbar", 
      :password_confirmation => "zomgbar", 
      :email => u.email
    }
    expect( response.body ).not_to be =~ /zomgbar/
  end

  it "should show errors when invalid" do
    post :create, :format => :json, :user => {
      :password => "zomgbar", 
      :password_confirmation => "zomgbar"
    }
    json = JSON.parse(response.body)
    expect( json['errors'] ).not_to be_blank
  end

  it "should not have duplicate email errors when email taken" do
    existing = User.make!
    user = User.make(:email => existing.email)
    post :create, :format => :json, :user => {
      :login => user.login,
      :email => user.email,
      :password => "zomgbar", 
      :password_confirmation => "zomgbar"
    }
    json = JSON.parse(response.body)
    expect( json['errors'].uniq.size ).to eq json['errors'].size
  end

  it "should assign a user to a site" do
    @site = Site.make!(:url => "test.host") # hoping the test host is the same across platforms...
    u = User.make
    post :create, :user => {:login => u.login, :password => "zomgbar", :password_confirmation => "zomgbar", :email => u.email}
    expect( User.find_by_login(u.login).site ).to eq @site
  end

  it "should assign a user to a site using inat_site_id param" do
    site1 = Site.make!( url: "test.host" )
    site2 = Site.make!
    u = User.make
    post :create, inat_site_id: site2.id, user: {
      login: u.login,
      password: "zomgbar",
      password_confirmation: "zomgbar",
      email: u.email
    }
    expect( User.find_by_login( u.login ).site ).to eq site2
  end

  it "should give the user the locale of the requested site" do
    locale = "es-MX"
    site = Site.make!( url: "test.host", preferred_locale: locale )
    u = User.make
    post :create, user: {
      login: u.login,
      password: "zomgbar",
      password_confirmation: "zomgbar",
      email: u.email
    }
    expect( User.find_by_login(u.login).locale ).to eq site.preferred_locale
  end

  it "should give the user the locale of the site specified by inat_site_id" do
    locale = "es-MX"
    site1 = Site.make!( url: "test.host" )
    site2 = Site.make!( preferred_locale: locale )
    u = User.make
    post :create, inat_site_id: site2.id, user: {
      login: u.login,
      password: "zomgbar",
      password_confirmation: "zomgbar",
      email: u.email
    }
    expect( User.find_by_login( u.login ).locale ).to eq locale
  end

  it "should accept time_zone" do
    u = User.make
    post :create, user: {
      login: u.login,
      password: "zomgbar",
      password_confirmation: "zomgbar",
      email: u.email,
      time_zone: "America/Los_Angeles"
    }
    u = User.find_by_login(u.login)
    expect( u.time_zone ).to eq "America/Los_Angeles"
  end
  it "should accept preferred_photo_license" do
    u = User.make
    post :create, user: {
      login: u.login,
      password: "zomgbar",
      password_confirmation: "zomgbar",
      email: u.email,
      preferred_photo_license: Observation::CC_BY
    }
    u = User.find_by_login(u.login)
    expect( u.preferred_photo_license ).to eq Observation::CC_BY
  end
end
