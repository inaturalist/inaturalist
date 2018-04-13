require File.dirname(__FILE__) + '/../spec_helper'

describe OauthTokensController, "create" do
  let(:app) { OauthApplication.make! }
  let(:user) { User.make! }
  it "should return a token for a normal user" do
    get :create, format: :json,
      client_id: app.uid,
      client_secret: app.secret,
      grant_type: "password",
      username: user.login,
      password: user.password
    expect( JSON.parse( response.body )["access_token"] ).not_to be_blank
  end
  it "should return a 401 for an incorrect password" do
    get :create, format: :json,
      client_id: app.uid,
      client_secret: app.secret,
      grant_type: "password",
      username: user.login,
      password: "#{user.password}foo"
    expect( response.code ).to eq "401"
  end
  it "should return a 403 for a suspended user" do
    user.suspend!
    get :create, format: :json,
      client_id: app.uid,
      client_secret: app.secret,
      grant_type: "password",
      username: user.login,
      password: user.password
    expect( response.code ).to eq "403"
  end
end