require File.dirname(__FILE__) + '/../spec_helper'

class InatConfig
  @site = Site.make!
  def self.set_site(site)
    @site = site
  end
  def site_id
    self.class.instance_variable_get(:@site) ?
      self.class.instance_variable_get(:@site).id : 1
  end
end

describe Users::RegistrationsController, "create" do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
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
    lambda {
      json = JSON.parse(response.body)
    }.should_not raise_error
  end

  it "should not return the password" do
    u = User.make
    post :create, :format => :json, :user => {
      :login => u.login, 
      :password => "zomgbar", 
      :password_confirmation => "zomgbar", 
      :email => u.email
    }
    response.body.should_not =~ /zomgbar/
  end

  it "should show errors when invalid" do
    post :create, :format => :json, :user => {
      :password => "zomgbar", 
      :password_confirmation => "zomgbar"
    }
    json = JSON.parse(response.body)
    json['errors'].should_not be_blank
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
    json['errors'].uniq.size.should eq json['errors'].size
  end

  it "should assign a user to a site" do
    @site = Site.make!(:url => "test.host") # hoping the test host is the same across platforms...
    InatConfig.set_site(@site)
    u = User.make
    post :create, :user => {:login => u.login, :password => "zomgbar", :password_confirmation => "zomgbar", :email => u.email}
    User.find_by_login(u.login).site.should eq @site
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
