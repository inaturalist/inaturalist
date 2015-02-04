require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "an IdentificationsController" do
  let(:user) { User.make! }
  let(:observation) { Observation.make! }

  describe "create" do
    it "should work" do
      observation.identifications.count.should eq 0
      t = Taxon.make!
      post :create, :format => :json, :identification => {
        :observation_id => observation.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      response.should be_success
      observation.reload
      observation.identifications.count.should eq 1
    end

    it "should include the observation in the response" do
      t = Taxon.make!
      post :create, :format => :json, :identification => {
        :observation_id => observation.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      response.should be_success
      json = JSON.parse(response.body)
      json['observation']['id'].should eq observation.id
    end

    it "should not include observation private coordinates" do
      t = Taxon.make!
      o = make_private_observation
      user.should_not eq o.user
      post :create, :format => :json, :identification => {
        :observation_id => o.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      response.should be_success
      json = JSON.parse(response.body)
      json['observation']['private_latitude'].should be_blank
    end

    it "should include the observation iconic_taxon_name" do
      load_test_taxa
      t = Taxon.make!
      @Pseudacris_regilla.iconic_taxon.should eq @Amphibia
      o = Observation.make!(:taxon => @Pseudacris_regilla)
      o.iconic_taxon_name.should eq @Amphibia.name
      post :create, :format => :json, :identification => {
        :observation_id => o.id,
        :taxon_id => t.id,
        :body => "i must eat them all"
      }
      response.should be_success
      json = JSON.parse(response.body)
      json['observation']['iconic_taxon_name'].should eq o.iconic_taxon_name
    end
  end

  describe "update" do
    let(:identification) { Identification.make!(:user => user) }
    it "should work" do
      lambda {
        put :update, :format => :json, :id => identification.id, :identification => {:body => "i must eat them all"}
        identification.reload
      }.should change(identification, :body)
    end
    
    it "should return json" do
      put :update, :format => :json, :id => identification.id, :identification => {:body => "i must eat them all"}
      json = JSON.parse(response.body)
      json['taxon_id'].should eq identification.taxon_id
    end
  end

  describe "destroy" do
    before(:all) do
      # some identification deletion callbacks need to happen after the transaction is complete
      DatabaseCleaner.strategy = :truncation
      ThinkingSphinx::Deltas.suspend!
    end

    after(:all) do
      DatabaseCleaner.strategy = :transaction
      ThinkingSphinx::Deltas.resume!
    end
    
    let(:identification) { Identification.make!(:user => user) }
    it "should work" do
      delete :destroy, :format => :json, :id => identification.id
      Identification.find_by_id(identification.id).should be_blank
    end

    it "should work if there's a pre-existing ident" do
      i = Identification.make!(:user => user, :observation => identification.observation)
      i.should be_current
      identification.reload
      identification.should_not be_current
      delete :destroy, :id => i.id
      Identification.find_by_id(i.id).should be_blank
      identification.reload
      identification.should be_current
    end
  end
end

describe IdentificationsController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "an IdentificationsController"
end

describe IdentificationsController, "devise authentication" do
  before { http_login(user) }
  it_behaves_like "an IdentificationsController"
end
