require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a AnnotationsController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make! }

  describe "create" do
    it "should return a UUID" do
      ctv = ControlledTermValue.make!
      post :create, format: :json, params: { annotation: {
        resource_type: "Observation",
        resource_id: observation.id,
        controlled_attribute_id: ctv.controlled_attribute.id,
        controlled_value_id: ctv.controlled_value.id
      } }
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json["uuid"] ).not_to be_blank
    end
  end
end

describe AnnotationsController, "oauth authentication" do
  let(:token) {
    double acceptable?: true,
    accessible?: true,
    resource_owner_id: user.id,
    application: OauthApplication.make!
  }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "a AnnotationsController"
end
