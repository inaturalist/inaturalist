require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an IdentificationsController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make! }

  describe "create" do
    it "should work" do
      expect(observation.identifications.count).to eq 0
      t = Taxon.make!
      post :create, :format => :json, :identification => {
        :observation_id => observation.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      observation.reload
      expect(observation.identifications.count).to eq 1
    end

    it "should include the observation in the response" do
      t = Taxon.make!
      post :create, :format => :json, :identification => {
        :observation_id => observation.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['observation']['id']).to eq observation.id
    end

    it "should not include observation private coordinates" do
      t = Taxon.make!
      o = make_private_observation
      expect(user).not_to eq o.user
      post :create, :format => :json, :identification => {
        :observation_id => o.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['observation']['private_latitude']).to be_blank
    end

    it "should include the observation iconic_taxon_name" do
      load_test_taxa
      t = Taxon.make!
      expect(@Pseudacris_regilla.iconic_taxon).to eq @Amphibia
      o = Observation.make!(:taxon => @Pseudacris_regilla)
      expect(o.iconic_taxon_name).to eq @Amphibia.name
      post :create, :format => :json, :identification => {
        :observation_id => o.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['observation']['iconic_taxon_name']).to eq o.iconic_taxon_name
    end
  end

  describe "update" do
    let(:identification) { Identification.make!(:user => user) }
    it "should work" do
      expect {
        put :update, :format => :json, :id => identification.id, :identification => {:body => "i must eat them all"}
        identification.reload
      }.to change(identification, :body)
    end
    
    it "should return json" do
      put :update, :format => :json, :id => identification.id, :identification => {:body => "i must eat them all"}
      json = JSON.parse(response.body)
      expect(json['taxon_id']).to eq identification.taxon_id
    end
  end

  describe "destroy" do
    before(:all) do
      # some identification deletion callbacks need to happen after the transaction is complete
      DatabaseCleaner.strategy = :truncation
    end

    after(:all) do
      DatabaseCleaner.strategy = :transaction
    end
    
    let(:identification) { Identification.make!(:user => user) }
    it "should work" do
      delete :destroy, :format => :json, :id => identification.id
      expect(Identification.find_by_id(identification.id)).to be_blank
    end

    it "should work if there's a pre-existing ident" do
      i = Identification.make!(:user => user, :observation => identification.observation)
      expect(i).to be_current
      identification.reload
      expect(identification).not_to be_current
      delete :destroy, :id => i.id
      expect(Identification.find_by_id(i.id)).to be_blank
      identification.reload
      expect(identification).to be_current
    end
  end
end

describe IdentificationsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "an IdentificationsController"
end

describe IdentificationsController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "an IdentificationsController"
end
