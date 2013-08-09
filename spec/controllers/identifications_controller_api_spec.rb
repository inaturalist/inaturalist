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
      observation.reload
      observation.identifications.count.should eq 1
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
    let(:identification) { Identification.make!(:user => user) }
    it "should work" do
      delete :destroy, :format => :json, :id => identification.id
      Identification.find_by_id(identification.id).should be_blank
    end
  end
end

describe IdentificationsController, "oauth authentication" do
  let(:token) { stub :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
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
