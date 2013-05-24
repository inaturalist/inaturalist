require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a TaxaController" do
  describe "show" do
    it "should include range kml url" do
      tr = TaxonRange.make!(:url => "http://foo.bar/range.kml")
      get :show, :format => :json, :id => tr.taxon_id
      response_taxon = JSON.parse(response.body)
      response_taxon['taxon_range_kml_url'].should eq tr.kml_url
    end
  end
end

describe TaxaController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { stub :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "a TaxaController"
end

describe TaxaController, "devise authentication" do
  let(:user) { User.make! }
  before do
    http_login(user)
  end
  it_behaves_like "a TaxaController"
end
