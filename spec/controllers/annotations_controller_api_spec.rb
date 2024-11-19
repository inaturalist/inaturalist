# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "a AnnotationsController" do
  let( :user ) { User.make! }
  let( :observation ) { Observation.make! }

  describe "create" do
    it "should return a UUID" do
      controlled_attribute = make_controlled_term_with_label
      controlled_value = make_controlled_value_with_label( nil, controlled_attribute )
      post :create, format: :json, params: { annotation: {
        resource_type: "Observation",
        resource_id: observation.id,
        controlled_attribute_id: controlled_attribute.id,
        controlled_value_id: controlled_value.id
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["uuid"] ).not_to be_blank
    end
  end
end

describe AnnotationsController, "oauth authentication" do
  let( :token ) do
    double(
      acceptable?: true,
      accessible?: true,
      resource_owner_id: user.id,
      application: OauthApplication.make!
    )
  end
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive( :doorkeeper_token ) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a AnnotationsController"
end
