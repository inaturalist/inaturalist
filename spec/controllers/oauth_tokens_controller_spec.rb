require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a token creator that blocks suspended users" do
  let(:app) { create :oauth_application }
  it "should return a token for a normal user" do
    post :create, format: :json, params: default_params_for_strategy
    json = JSON.parse( response.body )
    expect( json["access_token"] ).not_to be_blank
  end
  # Token requests return 400 for suspended users,
  # other API requests for suspended users return 401
  it "should return a 400 for a suspended user" do
    user.suspend!
    expect( user ).to be_suspended
    post :create, format: :json, params: default_params_for_strategy
    expect( response.code ).to eq "400"
    json = JSON.parse( response.body )
    expect( json["error"] ).to eq "invalid_grant"
    expect( json["error_description"] ).not_to be_blank
  end
  it "should include suspension details for a timed suspension" do
    user.update!( suspended_at: Time.now, suspension_reason: "policy violation", suspended_until: 1.week.from_now )
    expect( user ).to be_suspended
    post :create, format: :json, params: default_params_for_strategy
    expect( response.code ).to eq "400"
    json = JSON.parse( response.body )
    expect( json["error"] ).to eq "invalid_grant"
    expect( json["error_description"] ).to match( /policy violation/ )
    expect( json["suspended_until"] ).not_to be_blank
    expect( Time.parse( json["suspended_until"] ) ).to be_within( 1.minute ).of( 1.week.from_now )
  end
  it "should return null suspended_until for an indefinite suspension" do
    user.suspend!
    post :create, format: :json, params: default_params_for_strategy
    json = JSON.parse( response.body )
    expect( json ).to have_key( "suspended_until" )
    expect( json["suspended_until"] ).to be_nil
  end
  it "should return a token and unsuspend a user with an expired timed suspension" do
    admin = make_admin
    user.update_columns( suspended_at: 2.days.ago, suspended_until: 1.day.ago )
    post :create, format: :json, params: default_params_for_strategy
    json = JSON.parse( response.body )
    expect( json["access_token"] ).not_to be_blank
    user.reload
    expect( user ).not_to be_suspended
    expect( user.suspended_at ).to be_nil
  end
end

describe OauthTokensController, "with resource owner password credentials" do
  let(:app) { create :oauth_application }
  let(:user) { create :user }
  let(:default_params_for_strategy) { {
    client_id: app.uid,
    client_secret: app.secret,
    grant_type: "password",
    username: user.login,
    password: user.password
  } }

  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it "should return a 400 for an incorrect password" do
    get :create, format: :json, params: default_params_for_strategy.merge(
      password: "#{user.password}foo"
    )
    expect( response.code ).to eq "400"
  end

  describe "for a confirmed user" do
    it_behaves_like "a token creator that blocks suspended users"

    it "should return a 401 for an incorrect password" do
      post :create, format: :json, params: default_params_for_strategy.merge(
        password: "#{user.password}foo"
      )
      expect( response.code ).to eq "400"
    end
  end

  describe "for an unconfirmed user" do
    let(:user) { create :user, :as_unconfirmed }
    it "should not return a conventional spec-compliant error response" do
      post :create, format: :json, params: default_params_for_strategy
      expect( response.code ).to eq "200"
    end
  end

  it "should localize an error response" do
    locale = "fr"
    get :create, format: :json, params: default_params_for_strategy.merge(
      password: "#{user.password}foo",
      locale: locale
    )
    json = JSON.parse( response.body )
    expect( json["error_description"] ).to eq I18n.t( :invalid, scope: [:devise, :failure], locale: locale )
  end
end

describe OauthTokensController, "with an authorization code" do
  let(:user) { create :user }
  let(:auth_code) {
    # There has to be a better way to test this, but this works
    Doorkeeper::AccessGrant.create!(
      application: app,
      resource_owner_id: user.id,
      expires_in: 600,
      scopes: "write login",
      redirect_uri: app.redirect_uri
    ).token
  }
  let(:default_params_for_strategy) { {
    client_id: app.uid,
    client_secret: app.secret,
    grant_type: "authorization_code",
    redirect_uri: app.redirect_uri,
    code: auth_code
  } }
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a token creator that blocks suspended users"
end
