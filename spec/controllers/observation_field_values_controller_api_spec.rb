require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationFieldValuesController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make!(:user => user) }
  let(:observation_field) { ObservationField.make! }

  it "should create" do
    lambda {
      post :create, :format => :json, :observation_field_value => {
        :observation_id => observation.id,
        :observation_field_id => observation_field.id,
        :value => "foo"
      }
    }.should change(ObservationFieldValue, :count).by(1)
  end

  it "should update" do
    ofv = ObservationFieldValue.make!(:observation => observation, 
      :observation_field => observation_field, :value => "foo")
    put :update, :format => :json, :id => ofv.id, :observation_field_value => {
      :value => "bar"
    }
    ofv.reload
    ofv.value.should eq("bar")
  end

  it "should destroy" do
    ofv = ObservationFieldValue.make!(:observation => observation, :observation_field => observation_field)
    delete :destroy, :format => :json, :id => ofv.id
    ObservationFieldValue.find_by_id(ofv.id).should be_blank
  end
end

describe ObservationFieldValuesController, "oauth authentication" do
  let(:token) { stub :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "an ObservationFieldValuesController"
end

describe ObservationFieldValuesController, "devise authentication" do
  before do
    http_login user
  end
  it_behaves_like "an ObservationFieldValuesController"
end
