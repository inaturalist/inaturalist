# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

describe ProviderOauthController do
  describe "from google" do
    let( :client ) { create :oauth_application, trusted: true }
    let( :assertion_params ) do
      {
        assertion_type: "google",
        client_id: client.uid,
        assertion: "foo"
      }
    end

    before do
      stub_request( :get, "https://www.googleapis.com/userinfo/v2/me" ).to_return(
        status: 200,
        body: google_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    describe "with an email address" do
      let( :google_response ) do
        {
          id: Faker::Number.number.to_s,
          email: Faker::Internet.email
        }
      end

      it "should create a user" do
        expect( User.find_by_email( google_response[:email] ) ).to be_blank
        post :assertion, format: :json, params: assertion_params
        expect( User.find_by_email( google_response[:email] ) ).not_to be_blank
      end

      it "should not return a token for a new user" do
        expect( User.find_by_email( google_response[:email] ) ).to be_blank
        post :assertion, format: :json, params: assertion_params
        expect( response ).not_to be_successful
        expect( User.find_by_email( google_response[:email] ) ).not_to be_confirmed
        expect( JSON.parse( response.body )["access_token"] ).to be_blank
        expect( JSON.parse( response.body )["error"] ).not_to be_blank
      end

      it "should return a token for a confirmed user" do
        u = create :user, email: google_response[:email], confirmed_at: Time.now
        expect( u ).to be_confirmed
        post :assertion, format: :json, params: assertion_params
        expect( response ).to be_successful
        expect( JSON.parse( response.body )["access_token"] ).not_to be_blank
      end

      it "should return a token for an unconfirmed user who never received a confirmation email" do
        u = create :user, email: google_response[:email], confirmed_at: nil
        User.where( id: u.id ).update_all( confirmation_sent_at: nil )
        u.reload
        expect( u ).not_to be_confirmed
        expect( u.confirmation_sent_at ).to be_blank
        post :assertion, format: :json, params: assertion_params
        expect( response ).to be_successful
        expect( JSON.parse( response.body )["access_token"] ).not_to be_blank
      end

      it "should not return a token for a confirmed suspended user" do
        u = create :user, email: google_response[:email], confirmed_at: Time.now
        u.suspend!
        expect( u ).to be_confirmed
        expect( u ).to be_suspended
        post :assertion, format: :json, params: assertion_params
        expect( response ).not_to be_successful
        response_json = JSON.parse( response.body )
        expect( response_json["access_token"] ).to be_blank
        expect( response_json["error"] ).to eq "invalid_grant"
        expect( response_json["error_description"] ).not_to be_blank
      end

      it "should not return a token for a confirmed child without permission" do
        u = create :user, email: google_response[:email], confirmed_at: Time.now, birthday: 5.years.ago.to_date
        up = create( :user_parent, user: u )
        u.reload
        expect( up ).not_to be_donor
        expect( u.birthday ).to be > 13.years.ago
        expect( u ).to be_confirmed
        expect( u ).to be_child_without_permission
        post :assertion, format: :json, params: assertion_params
        expect( response ).not_to be_successful
        response_json = JSON.parse( response.body )
        expect( response_json["access_token"] ).to be_blank
        expect( response_json["error"] ).to eq "invalid_grant"
        expect( response_json["error_description"] ).not_to be_blank
      end

      describe "with a bad assertion_type" do
        let( :assertion_params ) do
          {
            assertion_type: "fragglerock",
            client_id: client.uid,
            assertion: "foo"
          }
        end
        # As the OAuth spec says
        it "should return 400" do
          post :assertion, format: :json, params: assertion_params
          expect( response.status ).to eq 400
        end
        it "should return a localized error_description" do
          locale = "es"
          post :assertion, format: :json, params: assertion_params.merge( locale: locale )
          response_json = JSON.parse( response.body )
          expect(
            response_json["error_description"]
          ).to eq I18n.t( "doorkeeper.errors.messages.access_denied", locale: locale )
          expect(
            response_json["error_description"]
          ).not_to eq I18n.t( "doorkeeper.errors.messages.access_denied", locale: "en" )
        end
        it "should return unsupported_grant_type error" do
          post :assertion, format: :json, params: assertion_params
          expect( response ).not_to be_successful
          response_json = JSON.parse( response.body )
          expect( response_json["error"] ).to eq "unsupported_grant_type"
        end
      end
      describe "with a bad client_id" do
        let( :assertion_params ) do
          {
            assertion_type: "google",
            client_id: "#{client.uid}sdgsdg",
            assertion: "foo"
          }
        end
        it "should return invalid_client error" do
          post :assertion, format: :json, params: assertion_params
          expect( response ).not_to be_successful
          response_json = JSON.parse( response.body )
          expect( response_json["error"] ).to eq "invalid_client"
        end
      end
      describe "with an untrusted client" do
        let( :client ) { create :oauth_application, trusted: false }
        it "should return unauthorized_client error" do
          post :assertion, format: :json, params: assertion_params
          expect( response ).not_to be_successful
          response_json = JSON.parse( response.body )
          expect( response_json["error"] ).to eq "unauthorized_client"
        end
      end


    end

    describe "without an email address" do
      let( :google_response ) { { id: Faker::Number.number.to_s } }
      it "should not create an account" do
        expect( User.find_by_email( google_response[:email] ) ).to be_blank
        post :assertion, params: assertion_params
        expect( User.find_by_email( google_response[:email] ) ).to be_blank
      end
      it "should respond with an error" do
        post :assertion, params: assertion_params
        response_json = JSON.parse( response.body )
        expect( response_json["error"] ).to eq "invalid_grant"
        expect( response_json["error_description"] ).not_to be_blank
      end
    end
  end
end
