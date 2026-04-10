# frozen_string_literal: true

require "spec_helper"

describe AdminController do
  let( :admin_user ) { make_admin }

  describe "user_content" do
    render_views

    it "should load correctly for the requested user id" do
      user = User.make!
      sign_in admin_user
      get :user_content, params: { id: user.id }
      expect( assigns( :display_user ) ).to eq user
      expect( response.body ).to match( /Manage content by.*#{user.login}/m )
    end
  end
end
