require File.dirname(__FILE__) + "/../spec_helper"

describe IdSummariesDemoController, "index" do
  let(:user) { User.make! }

  context "without admin mode enabled" do
    it "allows non-admin users" do
      sign_in user
      get :index
      expect( response ).to be_successful
    end
  end

  context "with admin mode enabled" do
    let(:admin) { make_admin }
    let(:message) { I18n.t( :you_dont_have_permission_to_do_that ) }

    it "allows admins" do
      sign_in admin
      get :index, params: { admin_mode: true }
      expect( response ).to be_successful
    end

    it "denies non-admin users for HTML requests" do
      sign_in user
      get :index, params: { admin_mode: true }
      expect( response ).to redirect_to( root_url )
      expect( flash[:error] ).to eq message
    end

    it "returns forbidden for JSON requests" do
      sign_in user
      get :index, params: { admin_mode: true }, format: :json
      expect( response ).to have_http_status( :forbidden )
      expect( JSON.parse( response.body )["error"] ).to eq message
    end

    it "returns forbidden for JS requests" do
      sign_in user
      get :index, params: { admin_mode: true }, format: :js
      expect( response ).to have_http_status( :forbidden )
      expect( response.body ).to eq message
    end
  end
end
