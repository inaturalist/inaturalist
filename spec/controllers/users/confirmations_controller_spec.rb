# frozen_string_literal: true

require "spec_helper"

describe Users::ConfirmationsController do
  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
    stub_request( :get, /#{INatAPIService::ENDPOINT}/ ).
      to_return( status: 200, body: "{ }",
        headers: { "Content-Type" => "application/json" } )
  end

  describe "show" do
    it "confirms the user with a valid token and redirects 302 to sign in" do
      user = create :user, confirmed_at: nil
      get :show, params: { confirmation_token: user.confirmation_token }

      expect( user.reload.confirmed? ).to be true
      expect( response ).to have_http_status( :found )
      expect( response ).to redirect_to( new_user_session_path( confirmed: true ) )
    end

    it "re-renders the form with a 200 for an invalid token" do
      get :show, params: { confirmation_token: "nonsense" }

      expect( response ).to have_http_status( :ok )
      expect( response ).to render_template( :new )
    end

    it "redirects an already confirmed signed in user to the dashboard" do
      user = create :user
      sign_in user
      get :show, params: { confirmation_token: "anything" }

      expect( response ).to redirect_to( dashboard_path )
    end
  end

  describe "create" do
    it "redirects 302 with the paranoid message for an unknown email" do
      post :create, params: { user: { email: "nobody@nowhere.test" } }

      expect( response ).to have_http_status( :found )
      expect( flash[:notice] ).to eq I18n.t( "devise.confirmations.send_paranoid_instructions" )
    end
  end
end
