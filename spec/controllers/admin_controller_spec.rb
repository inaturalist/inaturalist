# frozen_string_literal: true

require "spec_helper"

describe AdminController do
  let( :admin_user ) { make_admin }

  describe "user_content" do
    render_views

    it "should show an error about account age if user signed up in the last 60 days" do
      user = User.make!
      sign_in admin_user
      get :user_content, params: { id: user.id }
      expect( assigns( :display_user ) ).to eq user
      expect( response.body ).to match( /Manage content by.*#{user.login}/m )
    end
  end
end
