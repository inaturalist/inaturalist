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

    it "redirects 302 with the paranoid message for a nonexistent email" do
      post :create, params: { user: { email: "nobody@nowhere.test" } }
      expect( response ).to have_http_status( :found )
      expect( flash[:notice] ).to eq I18n.t( "devise.passwords.send_paranoid_instructions" )
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

    it "responds with a 200 when the reset token is invalid" do
      put :update, params: {
        user: {
          reset_password_token: "nonsense",
          password: "anything",
          password_confirmation: "anything"
        }
      }

      expect( response ).to have_http_status( :ok )
    end

    it "signs the user in and redirects 302 after a successful reset" do
      user = create :user
      raw_token = user.send_reset_password_instructions
      put :update, params: {
        user: {
          reset_password_token: raw_token,
          password: "new password 123",
          password_confirmation: "new password 123"
        }
      }

      expect( response ).to have_http_status( :found )
      expect( session["warden.user.user.key"] ).not_to be_blank
    end

    it "confirms an unconfirmed user after a successful reset" do
      user = create :user, confirmed_at: nil
      raw_token = user.send_reset_password_instructions
      put :update, params: {
        user: {
          reset_password_token: raw_token,
          password: "new password 123",
          password_confirmation: "new password 123"
        }
      }

      expect( user.reload.confirmed? ).to be true
    end
  end

  # We may be able to remove this route/controller action based on the
  # comment on PasswordsController#require_no_authentication_or_app_jwt
  # referencing the completed issue here https://github.com/inaturalist/iNaturalistAPI/issues/378
  describe "require_no_authentication" do
    let( :user ) { create :user }

    before do
      @request.env["devise.mapping"] = Devise.mappings[:user]
    end

    it "redirects a signed in user away from the reset form" do
      sign_in user
      get :new
      expect( response ).to have_http_status( :found )
      expect( flash[:alert] ).to eq I18n.t( "devise.failure.already_authenticated" )
    end

    it "allows an anonymous application JWT user to view the reset form" do
      request.env["HTTP_AUTHORIZATION"] = JsonWebToken.applicationToken
      get :new
      expect( response ).to have_http_status( :ok )
    end
  end
end
