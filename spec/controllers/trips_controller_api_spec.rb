# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper"

shared_examples_for "a TripsController" do
  describe "index" do
    it "should list trips" do
      Trip.make!
      get :index, format: :json
      expect( response ).to be_successful
      json = JSON.parse( response.body )
      expect( json ).not_to be_blank
    end

    it "should include pagination data in headers" do
      3.times { Trip.make! }
      total_entries = Trip.count
      get :index, format: :json, params: { page: 1, per_page: 2 }
      expect( response.headers["X-Total-Entries"].to_i ).to eq total_entries
      expect( response.headers["X-Page"].to_i ).to eq 1
      expect( response.headers["X-Per-Page"].to_i ).to eq 2
    end
  end

  describe "by_login" do
    it "should list trips by a user" do
      Trip.make!( user: user )
      Trip.make!
      get :by_login, format: :json, params: { login: user.login }
      json = JSON.parse( response.body )
      expect( json["trips"].size ).to eq 1
    end

    it "should filter by published=true" do
      t1 = Trip.make!( user: user, published_at: Time.now )
      Trip.make!( user: user, published_at: nil )
      get :by_login, format: :json, params: { login: user.login, published: true }
      json = JSON.parse( response.body )
      expect( json["trips"].detect {| t | t["id"] == t1.id } ).not_to be_blank
    end

    it "should filter by published=false" do
      Trip.make!( user: user, published_at: Time.now )
      t2 = Trip.make!( user: user, published_at: nil )
      get :by_login, format: :json, params: { login: user.login, published: false }
      json = JSON.parse( response.body )
      expect( json["trips"].detect {| t | t["id"] == t2.id } ).not_to be_blank
    end

    it "should filter by published=any" do
      Trip.make!( user: user, published_at: Time.now )
      Trip.make!( user: user, published_at: nil )
      get :by_login, format: :json, params: { login: user.login, published: "any" }
      json = JSON.parse( response.body )
      expect( json["trips"].size ).to eq 2
    end

    it "should not show drafts for people who didn't write them" do
      t = Trip.make!( published_at: nil )
      get :by_login, format: :json, params: { login: t.user.login, published: false }
      json = JSON.parse( response.body )
      expect( json["trips"] ).to be_blank
    end

    it "should include pagination data in headers" do
      3.times { Trip.make!( user: user ) }
      total_entries = user.trips.count
      get :by_login, format: :json, params: { login: user.login, published: "any", page: 1, per_page: 2 }
      expect( response.headers["X-Total-Entries"].to_i ).to eq( total_entries )
      expect( response.headers["X-Page"].to_i ).to eq( 1 )
      expect( response.headers["X-Per-Page"].to_i ).to eq( 2 )
    end
  end

  describe "show" do
    it "should work" do
      trip = Trip.make!( body: "this mah trip" )
      get :show, format: :json, params: { id: trip.id }
      expect( response.body ).to match( /this mah trip/ )
    end

    it "should include trip taxa" do
      tt = TripTaxon.make!
      get :show, format: :json, params: { id: tt.trip_id }
      json = JSON.parse( response.body )
      expect( json["trip"]["trip_taxa"] ).not_to be_blank
    end

    it "should include trip purposes" do
      tt = TripPurpose.make!
      get :show, format: :json, params: { id: tt.trip_id }
      json = JSON.parse( response.body )
      expect( json["trip"]["trip_purposes"] ).not_to be_blank
    end
  end

  describe "create" do
    it "should work" do
      trip = Trip.make
      c = Trip.count
      post :create, format: :json, params: { trip: trip.attributes }
      expect( Trip.count ).to eq c + 1
    end

    it "should allow nested trip taxa" do
      trip = Trip.make
      trip_taxon = TripTaxon.make( trip: trip )
      attrs = trip.attributes
      attrs[:trip_taxa_attributes] = {
        0 => trip_taxon.attributes
      }
      post :create, format: :json, params: { trip: attrs }
      t = Trip.last
      expect( t.trip_taxa.count ).to eq 1
    end

    it "should allow nested trip purposes" do
      trip = Trip.make
      trip_purpose = TripPurpose.make( trip: trip )
      attrs = trip.attributes
      attrs[:trip_purposes_attributes] = {
        0 => trip_purpose.attributes
      }
      post :create, format: :json, params: { trip: attrs }
      t = Trip.last
      expect( t.trip_purposes.count ).to eq 1
    end
  end

  describe "update" do
    it "should work" do
      t = Trip.make!( user: user )
      put :update, format: :json, params: { id: t.id, trip: { title: "this is a new title" } }
      t.reload
      expect( t.title ).to eq "this is a new title"
    end

    it "should allow nested trip taxa" do
      t = Trip.make!( user: user )
      tt = TripTaxon.make!( observed: false, trip: t )
      put :update, format: :json, params: { id: t.id, trip: {
        trip_taxa_attributes: {
          foo: tt.attributes.merge( observed: true )
        }
      } }
      tt.reload
      expect( tt ).to be_observed
    end

    it "should allow nested trip purposes" do
      t = Trip.make!( user: user )
      tp = TripPurpose.make!( complete: false, trip: t )
      put :update, format: :json, params: { id: t.id, trip: {
        trip_purposes_attributes: {
          tp.id => tp.attributes.merge( complete: true )
        }
      } }
      tp.reload
      expect( tp ).to be_complete
    end
  end

  describe "destroy" do
    it "should work" do
      trip = Trip.make!( user: user )
      delete :destroy, format: :json, params: { id: trip.id }
      t = Trip.find_by_id( trip.id )
      expect( t ).to be_blank
    end
  end
end

describe TripsController, "with authentication" do
  let( :user ) { User.make! }
  before do
    sign_in( user )
  end
  it_behaves_like "a TripsController"
end
