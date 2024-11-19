# frozen_string_literal: true

require "spec_helper"

describe ControlledTermsController do
  describe "create" do
    it "requires login" do
      controller.request.host = URI.parse( Site.default.url ).host
      post :create, params: { controlled_term: { uri: "userterm" } }
      expect( response ).not_to be_successful
      expect( response.response_code ).to eq 302
      expect( response.location ).to eq new_user_session_url
    end

    it "requires admin login" do
      sign_in( User.make! )
      expect { post :create, params: { controlled_term: { uri: "curatorterm" } } }.to throw_symbol( :abort )
      expect( response ).not_to be_successful
      expect( response.response_code ).to eq 303
    end

    it "allows admins to create terms" do
      sign_in( make_admin )
      expect do
        post :create, params: {
          controlled_term: {
            uri: "adminterm",
            controlled_term_label: {
              label: "foo",
              definition: "bar"
            }
          }
        }
      end.to change( ControlledTerm, :count ).by( 1 )
      expect( ControlledTerm.last.uri ).to eq "adminterm"
    end
  end
end
