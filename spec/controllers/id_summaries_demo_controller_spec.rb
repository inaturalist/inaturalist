require File.dirname(__FILE__) + "/../spec_helper"

describe IdSummariesDemoController, "index" do
  let(:user) { User.make! }

  context "when no allowlist is configured" do
    before do
      allow( CONFIG ).to receive_message_chain( :id_summaries_demo, :allowed_user_ids ).and_return( nil )
    end

    it "allows admins" do
      sign_in make_admin
      get :index
      expect( response ).to be_successful
    end
  end

  context "when allowlist is configured" do
    let(:authorized_user) { User.make! }
    let(:allowlist) { [authorized_user.id] }

    before do
      allow( CONFIG ).to receive_message_chain( :id_summaries_demo, :allowed_user_ids ).and_return( allowlist )
    end

    it "allows listed users" do
      sign_in authorized_user
      get :index
      expect( response ).to be_successful
    end

    it "denies unlisted non-admin users" do
      sign_in user
      get :index
      expect( response ).to redirect_to( root_url )
      expect( flash[:error] ).to eq I18n.t( :you_dont_have_permission_to_do_that )
    end
  end
end
