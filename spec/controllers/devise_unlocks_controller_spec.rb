# frozen_string_literal: true

require "spec_helper"

# The app does not customize Devise::UnlocksController, so these specs pin the
# behavior of the stock controller and its gem-provided views, which have no
# other coverage in this app
describe Devise::UnlocksController do
  let( :user ) { create :user }

  before do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "create" do
    it "resends unlock instructions for a locked user and redirects 302" do
      user.lock_access!
      expect do
        post :create, params: { user: { email: user.email } }
      end.to change( ActionMailer::Base.deliveries, :size ).by( 1 )
      expect( response ).to have_http_status( :found )
    end

    it "redirects 302 for an unknown email" do
      post :create, params: { user: { email: "nobody@nowhere.test" } }
      expect( response ).to have_http_status( :found )
    end
  end

  describe "show" do
    it "unlocks the account with a valid token and redirects 302" do
      user.lock_access!
      raw_token = user.send_unlock_instructions
      get :show, params: { unlock_token: raw_token }
      expect( user.reload.access_locked? ).to be false
      expect( response ).to have_http_status( :found )
      expect( response ).to redirect_to( new_user_session_path )
    end

    it "re-renders the form with a 200 for an invalid token" do
      get :show, params: { unlock_token: "nonsense" }
      # This status is devise 4.9's error_status, which must remain :ok
      expect( response ).to have_http_status( :ok )
      expect( response ).to render_template( :new )
    end
  end
end
