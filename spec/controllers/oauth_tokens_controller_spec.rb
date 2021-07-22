require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a token creator that blocks suspended users" do
  let(:app) { OauthApplication.make! }
  let(:user) { User.make! }
  it "should return a token for a normal user" do
    get :create, format: :json, params: default_params_for_strategy
    json = JSON.parse( response.body )
    expect( json["access_token"] ).not_to be_blank
  end
  it "should return a 403 for a suspended user" do
    user.suspend!
    get :create, format: :json, params: default_params_for_strategy
    expect( response.code ).to eq "403"
  end
end

describe OauthTokensController, "with resource owner password credentials" do
  let(:app) { OauthApplication.make! }
  let(:user) { User.make! }
  let(:default_params_for_strategy) { {
    client_id: app.uid,
    client_secret: app.secret,
    grant_type: "password",
    username: user.login,
    password: user.password
  } }
  it_behaves_like "a token creator that blocks suspended users"
  it "should return a 401 for an incorrect password" do
    get :create, format: :json, params: default_params_for_strategy.merge(
      password: "#{user.password}foo"
    )
    expect( response.code ).to eq "400"
  end
end

describe OauthTokensController, "with an authorization code" do
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
  it_behaves_like "a token creator that blocks suspended users"
end
