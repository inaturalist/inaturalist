# frozen_string_literal: true

require "spec_helper"

describe Users::PasswordsController do
  describe "create" do
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

  describe "update" do
    render_views

    before do
      @request.env["devise.mapping"] = Devise.mappings[:user]
    end

    it "renders an error if the password reset token is invalid" do
      put :update, params: {
        user: {
          reset_password_token: "nonsense",
          password: "anything",
          password_confirmation: "anything"
        }
      }
      expect( response.body ).to have_tag( ".alert", text: /The reset password token is invalid/ )
    end
  end
end
