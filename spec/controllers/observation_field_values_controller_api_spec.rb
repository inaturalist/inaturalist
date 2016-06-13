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
      expect(json.size).to eq 1
      get :index, format: 'json', type: "bargleplax"
      json = JSON.parse(response.body)
      expect(json.size).to eq 0
    end

    it "should filter by quality grade" do
      o = make_research_grade_observation
      ofv = ObservationFieldValue.make!(observation: o, observation_field: observation_field)
      get :index, format: 'json', type: observation_field.datatype, quality_grade: 'research'
      json = JSON.parse(response.body)
      expect(json.size).to eq 1
      get :index, format: 'json', type: observation_field.datatype, quality_grade: 'casual'
      json = JSON.parse(response.body)
      expect(json.size).to eq 0
    end

    describe "taxon in response" do
      let(:t) { Taxon.make!(source: Source.make!, source_identifier: 12345) }
      let(:tst) { TaxonSchemeTaxon.make!(taxon: t, source_identifier: 12345) }
      let(:of) { ObservationField.make!(datatype: ObservationField::TAXON) }
      let(:ofv) { ObservationFieldValue.make!(observation_field: of, value: t.id) }

      before do
        expect( tst ).to be_valid
        expect( ofv ).to be_valid
      end

      it "should be there in the response for a taxon field" do
        get :index, format: 'json', type: of.datatype
        json = JSON.parse(response.body)
        o = json.first
        expect( o['taxon'] ).not_to be_blank
      end
      it "the taxon should have source" do
        get :index, format: 'json', type: of.datatype
        json = JSON.parse(response.body)
        o = json.first
        expect( o['taxon']['source'] ).not_to be_blank
      end
      it "the taxon should have source identifier" do
        get :index, format: 'json', type: of.datatype
        json = JSON.parse(response.body)
        o = json.first
        expect( o['taxon']['source_identifier'] ).not_to be_blank
      end
      it "the taxon should have taxon scheme taxa" do
        get :index, format: 'json', type: of.datatype
        json = JSON.parse(response.body)
        o = json.first
        expect( o['taxon']['taxon_scheme_taxa'] ).not_to be_blank
        expect( o['taxon']['taxon_scheme_taxa'][0]['taxon_scheme'] ).not_to be_blank
      end
    end
  end

  describe "create" do
    it "should work" do
      expect {
        post :create, :format => :json, :observation_field_value => {
          :observation_id => observation.id,
          :observation_field_id => observation_field.id,
          :value => "foo"
        }
      }.to change(ObservationFieldValue, :count).by(1)
    end

    it "should provie an appropriate response for blank observation id" do
      post :create, :format => :json,  :observation_field_value => {
        :observation_id => nil,
        :observation_field_id => observation_field.id,
        :value => "foo"
      }
      expect(response.status).to eq 422
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
      expect(json['errors']).to be_blank
    end

    it "should ignore ID of zero" do
      expect {
        post :create, format: 'json', observation_field_value: {
          id: 0,
          observation_id: observation.id,
          observation_field_id: observation_field.id,
          value: "foo"
        }
      }.not_to raise_error
    end
  end

  it "should update" do
    ofv = ObservationFieldValue.make!(:observation => observation, 
      :observation_field => observation_field, :value => "foo")
    put :update, :format => :json, :id => ofv.id, :observation_field_value => {
      :value => "bar"
    }
    ofv.reload
    expect(ofv.value).to eq("bar")
  end

  it "should destroy" do
    ofv = ObservationFieldValue.make!(:observation => observation, :observation_field => observation_field)
    delete :destroy, :format => :json, :id => ofv.id
    expect(ObservationFieldValue.find_by_id(ofv.id)).to be_blank
  end

  it "should destroy values on others observations" do
    ofv = ObservationFieldValue.make!(observation: Observation.make!,
      observation_field: observation_field, user_id: user.id)
    delete :destroy, format: :json, id: ofv.id
    expect(ObservationFieldValue.find_by_id(ofv.id)).to be_blank
  end
end

describe ObservationFieldValuesController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "an ObservationFieldValuesController"
end

describe ObservationFieldValuesController, "devise authentication" do
  before do
    http_login user
  end
  it_behaves_like "an ObservationFieldValuesController"
end
