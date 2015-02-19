require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationFieldValuesController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make!(:user => user) }
  let(:observation_field) { ObservationField.make! }

  describe "index" do
    it "should filter by type" do
      ofv = ObservationFieldValue.make!(observation: observation, observation_field: observation_field)
      get :index, format: 'json', type: observation_field.datatype
      json = JSON.parse(response.body)
      json.size.should eq 1
      get :index, format: 'json', type: "bargleplax"
      json = JSON.parse(response.body)
      json.size.should eq 0
    end

    it "should filter by quality grade" do
      o = make_research_grade_observation
      ofv = ObservationFieldValue.make!(observation: o, observation_field: observation_field)
      get :index, format: 'json', type: observation_field.datatype, quality_grade: 'research'
      json = JSON.parse(response.body)
      json.size.should eq 1
      get :index, format: 'json', type: observation_field.datatype, quality_grade: 'casual'
      json = JSON.parse(response.body)
      json.size.should eq 0
    end
  end

  describe "create" do
    it "should work" do
      lambda {
        post :create, :format => :json, :observation_field_value => {
          :observation_id => observation.id,
          :observation_field_id => observation_field.id,
          :value => "foo"
        }
      }.should change(ObservationFieldValue, :count).by(1)
    end

    # it "should not allow blank values" do
    #   lambda {
    #     post :create, :format => :json, :observation_field_value => {
    #       :observation_id => observation.id,
    #       :observation_field_id => observation_field.id,
    #       :value => ""
    #     }
    #   }.should_not change(ObservationFieldValue, :count).by(1)
    # end

    it "should provie an appropriate response for blank observation id" do
      post :create, :format => :json,  :observation_field_value => {
        :observation_id => nil,
        :observation_field_id => observation_field.id,
        :value => "foo"
      }
      response.status.should eq 422
    end
    
    it "should allow blank values if coming from an iNat mobile app" do
      o = make_mobile_observation
      of = ObservationField.make!(:datatype => "date")
      post :create, :format => :json, :observation_field_value => {
        :observation_id => o.id,
        :observation_field_id => of.id,
        :value => ""
      }
      json = JSON.parse(response.body)
      json['errors'].should be_blank
    end

    # it "should now allow invalid dates" do
    #   of = ObservationField.make!(:datatype => "date")
    #   post :create, :format => :json, :observation_field_value => {
    #     :observation_id => observation.id,
    #     :observation_field_id => of.id,
    #     :value => "2013-jfhgh"
    #   }
    #   json = JSON.parse(response.body)
    #   json['errors'].should_not be_blank
    # end

    # it "should now allow invalid datetimes" do
    #   of = ObservationField.make!(:datatype => "datetime")
    #   post :create, :format => :json, :observation_field_value => {
    #     :observation_id => observation.id,
    #     :observation_field_id => of.id,
    #     :value => "2013-jfhgh"
    #   }
    #   json = JSON.parse(response.body)
    #   json['errors'].should_not be_blank
    # end

    # it "should now allow invalid times" do
    #   of = ObservationField.make!(:datatype => "date")
    #   post :create, :format => :json, :observation_field_value => {
    #     :observation_id => observation.id,
    #     :observation_field_id => of.id,
    #     :value => "1pm"
    #   }
    #   json = JSON.parse(response.body)
    #   json['errors'].should_not be_blank
    # end
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
