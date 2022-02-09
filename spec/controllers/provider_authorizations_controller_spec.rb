# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

OmniAuth.config.test_mode = true

describe ProviderAuthorizationsController, "create" do
  let(:auth_hash) { Faker::Omniauth.facebook }
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new( auth_hash )
    request.env["devise.mapping"] = Devise.mappings[:user]
    request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:facebook]
  end
  after do
    OmniAuth.config.mock_auth[:facebook] = nil
  end

  it "should create a user with one provider_authorization" do
    post :create, params: { provider: "facebook" }
    u = User.find_by_email( auth_hash[:info][:email] )
    expect( u.provider_authorizations ).not_to be_blank
  end
  it "should create a user with a confirmation_token" do
    post :create, params: { provider: "facebook" }
    u = User.find_by_email( auth_hash[:info][:email] )
    expect( u ).not_to be_confirmed
    expect( u.confirmation_token ).not_to be_blank
  end
  it "should send a confirmation email" do
    expect {
      post :create, params: { provider: "facebook" }
    }.to change( ActionMailer::Base.deliveries, :size ).by( 1 )
  end
  it "should not create a user if there was no email address" do
    request.env["omniauth.auth"][:info][:email] = nil
    expect {
      post :create, params: { provider: "facebook" }
    }.not_to change( User, :count )
  end
end
