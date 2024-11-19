# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../../spec_helper"

describe Users::PasswordsController, "create" do
  let( :user ) { create :user }

  before do
    expect( user ).to be_valid
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  it "should deliver an email with a CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    expect do
      post :create, params: { user: { email: user.email } }
    end.to change( ActionMailer::Base.deliveries, :size ).by( 1 )
    ActionController::Base.allow_forgery_protection = false
  end

  it "should deliver an email with an application JWT" do
    expect do
      request.env["Content-Type"] = "application/json"
      request.env["HTTP_AUTHORIZATION"] = JsonWebToken.applicationToken
      post :create, params: { user: { email: user.email } }
    end.to change( ActionMailer::Base.deliveries, :size ).by( 1 )
  end
end
