require "spec_helper"

describe ControlledTermsController do

  describe "create" do
    it "requires login" do
      post :create, controlled_term: { uri: "userterm" }
      expect(response).not_to be_success
      expect(response.response_code).to eq 302
      expect(response.location).to eq new_user_session_url
    end

    it "requires admin login" do
      http_login(User.make!)
      post :create, controlled_term: { uri: "curatorterm" }
      expect(response).not_to be_success
      expect(response.response_code).to eq 303
    end

    it "allows admins to create terms" do
      http_login(make_admin)
      expect {
        post :create, controlled_term: { uri: "adminterm" }
      }.to change(ControlledTerm, :count).by(1)
      expect(ControlledTerm.last.uri).to eq "adminterm"
    end
  end

end
