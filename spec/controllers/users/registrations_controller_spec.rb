# frozen_string_literal: true

require "spec_helper"

# HTML behavior for registrations. JSON behavior is covered in
# spec/controllers/registrations_controller_api_spec.rb. These specs pin the
# statuses used by devise's responder, which must not change with devise
# 4.9's configurable error_status and redirect_status
describe Users::RegistrationsController do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    stub_request( :get, /#{INatAPIService::ENDPOINT}/ ).
      to_return( status: 200, body: "{ }",
        headers: { "Content-Type" => "application/json" } )
  end

  describe "create" do
    it "re-renders the form with a 200 on validation failure" do
      post :create, params: { user: {
        password: "zomgbar",
        password_confirmation: "zomgbar"
      } }
      expect( response ).to have_http_status( :ok )
      expect( response ).to render_template( :new )
    end

    it "redirects with a 302 on success" do
      u = User.make
      post :create, params: { user: {
        login: u.login,
        email: u.email,
        password: "zomgbar",
        password_confirmation: "zomgbar"
      } }
      expect( response ).to have_http_status( :found )
    end
  end

  describe "update" do
    let( :user ) { create :user }

    before do
      sign_in user
    end

    it "re-renders the form with a 200 when the current password is wrong" do
      put :update, params: { user: {
        password: "new password 123",
        password_confirmation: "new password 123",
        current_password: "notmypassword"
      } }
      expect( response ).to have_http_status( :ok )
      expect( response ).to render_template( :edit )
    end

    it "redirects with a 302 on success" do
      put :update, params: { user: {
        password: "new password 123",
        password_confirmation: "new password 123",
        current_password: "monkey"
      } }
      expect( response ).to have_http_status( :found )
      expect( user.reload.valid_password?( "new password 123" ) ).to be true
    end
  end
end
