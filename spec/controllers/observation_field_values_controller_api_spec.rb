require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an ObservationFieldValuesController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make!(user: user) }
  let(:observation_field) { ObservationField.make! }

  describe "create" do
    it "should work" do
      expect {
        post :create, format: :json, params: { observation_field_value: {
          observation_id: observation.id,
          observation_field_id: observation_field.id,
          value: "foo"
        } }
      }.to change(ObservationFieldValue, :count).by(1)
    end

    it "should provie an appropriate response for blank observation id" do
      post :create, format: :json, params: { observation_field_value: {
        observation_id: nil,
        observation_field_id: observation_field.id,
        value: "foo"
      } }
      expect(response.status).to eq 422
    end

    it "should allow blank values if coming from an iNat mobile app" do
      o = make_mobile_observation
      of = ObservationField.make!(datatype: "date")
      post :create, format: :json, params: { observation_field_value: {
        observation_id: o.id,
        observation_field_id: of.id,
        value: ""
      } }
      json = JSON.parse(response.body)
      expect(json['errors']).to be_blank
    end

    it "should ignore ID of zero" do
      expect {
        post :create, format: 'json', params: { observation_field_value: {
          id: 0,
          observation_id: observation.id,
          observation_field_id: observation_field.id,
          value: "foo"
        } }
      }.not_to raise_error
    end

    it "should not work if the observer prefers not to receive from the creator" do
      u = User.make!( prefers_observation_fields_by: User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER )
      o = Observation.make!( user: u )
      post :create, format: :json, params: { observation_field_value: {
        observation_id: o.id,
        observation_field_id: observation_field.id,
        value: "foo"
      } }
      expect( response.status ).to eq 422
    end
  end

  describe "update" do
    it "should update" do
      ofv = ObservationFieldValue.make!(observation: observation,
        observation_field: observation_field, value: "foo")
      put :update, format: :json, params: { id: ofv.id, observation_field_value: {
        value: "bar"
      } }
      ofv.reload
      expect(ofv.value).to eq("bar")
    end
    it "should not work if the observer prefers not to receive from the updater" do
      u = User.make!( prefers_observation_fields_by: User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER )
      o = Observation.make!( user: u )
      ofv = ObservationFieldValue.make!(
        observation: o,
        user: u,
        observation_field: observation_field
      )
      put :update, format: :json, params: { id: ofv.id, observation_field_value: {
        value: "#{ofv.value} foo"
      } }
      expect( response.status ).to eq 422
    end
  end

  describe "destroy" do
    it "should work on an OFV added by others to your observation" do
      ofv = ObservationFieldValue.make!(
        observation: observation,
        observation_field: observation_field
      )
      delete :destroy, format: :json, params: { id: ofv.id }
      expect( ObservationFieldValue.find_by_id( ofv.id ) ).to be_blank
    end
    it "should work on an OFV you added to an obs by someone else" do
      ofv = ObservationFieldValue.make!(
        observation: Observation.make!,
        observation_field: observation_field,
        user_id: user.id
      )
      delete :destroy, format: :json, params: { id: ofv.id }
      expect( ObservationFieldValue.find_by_id( ofv.id ) ).to be_blank
    end
    it "should fail if the observation is in a project that requires this field" do
      pof = ProjectObservationField.make!(
        observation_field: observation_field,
        required: true
      )
      obs = Observation.make!( user: user )
      ofv = ObservationFieldValue.make!(
        user: user,
        observation_field: observation_field,
        observation: obs
      )
      po = ProjectObservation.make!( project: pof.project, observation: obs )
      expect( po ).to be_valid
      delete :destroy, format: :json, params: { id: ofv.id }
      expect( ObservationFieldValue.find_by_id( ofv.id ) ).not_to be_blank
    end
  end

end

describe ObservationFieldValuesController, "oauth authentication" do
  let(:token) { double acceptable?: true, accessible?: true, resource_owner_id: user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
  it_behaves_like "an ObservationFieldValuesController"
end
