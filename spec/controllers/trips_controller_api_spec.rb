require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a TripsController" do
  describe "index" do
    it "should list trips" do
      trip = Trip.make!
      get :index, :format => :json
      response.should be_success
      json = JSON.parse(response.body)
      json.should_not be_blank
    end

    it "should include pagination data in headers" do
      3.times { Trip.make! }
      total_entries = Trip.count
      get :index, :format => :json, :page => 1, :per_page => 2
      response.headers["X-Total-Entries"].to_i.should eq(total_entries)
      response.headers["X-Page"].to_i.should eq(1)
      response.headers["X-Per-Page"].to_i.should eq(2)
    end
  end

  describe "by_login" do
    it "should list trips by a user" do
      t1 = Trip.make!(:user => user)
      t2 = Trip.make!
      get :by_login, :format => :json, :login => user.login
      json = JSON.parse(response.body)
      json['trips'].size.should eq 1
    end

    it "should filter by published=true" do
      t1 = Trip.make!(:user => user, :published_at => Time.now)
      t2 = Trip.make!(:user => user, :published_at => nil)
      get :by_login, :format => :json, :login => user.login, :published => true
      json = JSON.parse(response.body)
      json['trips'].detect{|t| t['id'] == t1.id}.should_not be_blank
    end

    it "should filter by published=false" do
      t1 = Trip.make!(:user => user, :published_at => Time.now)
      t2 = Trip.make!(:user => user, :published_at => nil)
      get :by_login, :format => :json, :login => user.login, :published => false
      json = JSON.parse(response.body)
      json['trips'].detect{|t| t['id'] == t2.id}.should_not be_blank
    end

    it "should filter by published=any" do
      t1 = Trip.make!(:user => user, :published_at => Time.now)
      t2 = Trip.make!(:user => user, :published_at => nil)
      get :by_login, :format => :json, :login => user.login, :published => "any"
      json = JSON.parse(response.body)
      json['trips'].size.should eq 2
    end

    it "should not show drafts for people who didn't write them" do
      t = Trip.make!(:published_at => nil)
      get :by_login, :format => :json, :login => t.user.login, :published => false
      json = JSON.parse(response.body)
      json['trips'].should be_blank
    end

    it "should include pagination data in headers" do
      3.times { Trip.make!(:user => user) }
      total_entries = user.trips.count
      get :by_login, :format => :json, :login => user.login, :published => "any", :page => 1, :per_page => 2
      response.headers["X-Total-Entries"].to_i.should eq(total_entries)
      response.headers["X-Page"].to_i.should eq(1)
      response.headers["X-Per-Page"].to_i.should eq(2)
    end
  end

  describe "show" do
    it "should work" do
      trip = Trip.make!(:body => "this mah trip")
      get :show, :format => :json, :id => trip.id
      response.body.should match /this mah trip/
    end

    it "should include trip taxa" do
      tt = TripTaxon.make!
      get :show, :format => :json, :id => tt.trip_id
      json = JSON.parse(response.body)
      json['trip']['trip_taxa'].should_not be_blank
    end

    it "should include trip purposes" do
      tt = TripPurpose.make!
      get :show, :format => :json, :id => tt.trip_id
      json = JSON.parse(response.body)
      json['trip']['trip_purposes'].should_not be_blank
    end
  end

  describe "create" do
    it "should work" do
      trip = Trip.make
      c = Trip.count
      post :create, :format => :json, :trip => trip.attributes
      Trip.count.should eq c+1
    end

    it "should allow nested trip taxa" do
      trip = Trip.make
      trip_taxon = TripTaxon.make(:trip => trip)
      attrs = trip.attributes
      attrs[:trip_taxa_attributes] = {
        0 => trip_taxon.attributes
      }
      post :create, :format => :json, :trip => attrs
      t = Trip.last
      t.trip_taxa.count.should eq 1
    end

    it "should allow nested trip purposes" do
      trip = Trip.make
      trip_purpose = TripPurpose.make(:trip => trip)
      attrs = trip.attributes
      attrs[:trip_purposes_attributes] = {
        0 => trip_purpose.attributes
      }
      post :create, :format => :json, :trip => attrs
      t = Trip.last
      t.trip_purposes.count.should eq 1
    end
  end

  describe "update" do
    it "should work" do
      t = Trip.make!(:user => user)
      put :update, :format => :json, :id => t.id, :trip => {:title => "this is a new title"}
      t.reload
      t.title.should eq "this is a new title"
    end

    it "should allow nested trip taxa" do
      t = Trip.make!(:user => user)
      tt = TripTaxon.make!(:observed => false, :trip => t)
      put :update, :format => :json, :id => t.id, :trip => {
        :trip_taxa_attributes => {
          :foo => tt.attributes.merge(:observed => true)
        }
      }
      tt.reload
      tt.should be_observed
    end

    it "should allow nested trip purposes" do
      t = Trip.make!(:user => user)
      tp = TripPurpose.make!(:complete => false, :trip => t)
      put :update, :format => :json, :id => t.id, :trip => {
        :trip_purposes_attributes => {
          tp.id => tp.attributes.merge(:complete => true)
        }
      }
      tp.reload
      tp.should be_complete
    end
  end

  describe "destroy" do
    it "should work" do
      trip = Trip.make!(:user => user)
      delete :destroy, :format => :json, :id => trip.id
      t = Trip.find_by_id(trip.id)
      t.should be_blank
    end
  end
end

describe TripsController, "oauth authentication" do
  let(:user) { User.make! }
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id, :application => OauthApplication.make! }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    controller.stub(:doorkeeper_token) { token }
  end
  it_behaves_like "a TripsController"
end

describe TripsController, "devise authentication" do
  let(:user) { User.make! }
  before do
    http_login(user)
  end
  it_behaves_like "a TripsController"
end
