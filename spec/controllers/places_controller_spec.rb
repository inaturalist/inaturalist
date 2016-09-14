require File.dirname(__FILE__) + '/../spec_helper'

describe PlacesController do
  describe "create" do
    it "should make a place with no default type" do
      user = User.make!
      sign_in user
      expect {
        post :create, :place => {
          :name => "Pine Island Ridge Natural Area", 
          :latitude => 26.08, 
          :longitude => -80.27}
      }.to change(Place, :count).by(1)
      expect(Place.last.place_type).to be_blank
    end

    it "creates places with geojson" do
      user = User.make!
      sign_in user
      post :create, place: {
        name: "Test geojson",
        latitude: 30,
        longitude: 30
      }, geojson: test_place_geojson
      p = Place.last
      expect( p.name ).to eq "Test geojson"
      expect( p.place_geometry ).to_not be_nil
    end

    it "does not allow non admins to create huge places" do
      user = User.make!
      sign_in user
      post :create, place: {
        name: "Test non-admin geojson",
        latitude: 30,
        longitude: 30
      }, geojson: test_place_geojson(:huge)
      p = Place.last
      expect( p.name ).to eq "Test non-admin geojson"
      expect( p.place_geometry ).to be_nil
    end

    it "allows admins to create huge places" do
      user = make_admin
      sign_in user
      post :create, place: {
        name: "Test admin geojson",
        latitude: 30,
        longitude: 30
      }, geojson: test_place_geojson(:huge)
      p = Place.last
      expect( p.name ).to eq "Test admin geojson"
      expect( p.place_geometry ).to_not be_nil
    end
  end

  describe "update" do
    it "updates places with geojson" do
      user = User.make!
      p = Place.make!(user: user)
      sign_in user
      put :update, id: p.id, place: {
        name: "Test geojson",
        latitude: 30,
        longitude: 30
      }, geojson: test_place_geojson
      p = Place.last
      expect( p.name ).to eq "Test geojson"
      expect( p.place_geometry ).to_not be_nil
    end

    it "does not allow non admins to create huge places" do
      user = User.make!
      p = Place.make!(user: user)
      sign_in user
      put :update, id: p.id, place: {
        name: "Test non-admin geojson",
        latitude: 30,
        longitude: 30
      }, geojson: test_place_geojson(:huge)
      p = Place.last
      expect( p.name ).to eq "Test non-admin geojson"
      expect( p.place_geometry ).to be_nil
    end

    it "allows admins to create huge places" do
      user = make_admin
      p = Place.make!(user: user)
      sign_in user
      put :update, id: p.id, place: {
        name: "Test admin geojson",
        latitude: 30,
        longitude: 30
      }, geojson: test_place_geojson(:huge)
      p = Place.last
      expect( p.name ).to eq "Test admin geojson"
      expect( p.place_geometry ).to_not be_nil
    end
  end

  describe "destroy" do
    let(:user) { User.make! }
    let(:place) { Place.make!(:user => user) }
    before do
      sign_in user
    end
    it "should delete the place" do
      expect(place).not_to be_blank
      expect {
        delete :destroy, :id => place.id
      }.to change(Place, :count).by(-1)
    end
    it "should fail if projects are using the place" do
      p = Project.make!(place: place)
      delete :destroy, id: place.id
      expect( Place.find_by_id(place.id) ).not_to be_blank
    end
    it "should fail if projects are using the place in rules" do
      p = Project.make!
      p.project_observation_rules.create(operand: place, operator: 'observed_in_place?')
      delete :destroy, id: place.id
      expect( Place.find_by_id(place.id) ).not_to be_blank
    end
  end

  describe "search" do
    let(:place) { Place.make!(:name => 'Panama') }
    let(:another_place) { Place.make!(:name => 'Norway') }
    it "should return results in HTML" do
      expect(place).not_to be_blank
      expect(Place).to receive(:elastic_paginate).and_return([ place, another_place ])
      get :search, :q => place.name
      expect(response.content_type).to eq"text/html"
    end
    it "should redirect with only one result in HTML" do
      expect(Place).to receive(:elastic_paginate).and_return([ place ])
      get :search, :q => place.name
      expect(response).to be_redirect
    end
    it "should not redirect with only one result in JSON" do
      expect(Place).to receive(:elastic_paginate).and_return([ place ])
      get :search, :q => place.name, :format => :json
      expect(response).not_to be_redirect
    end
    it "should return results in JSON, with html" do
      place.html = 'the html'
      expect(Place).to receive(:elastic_paginate).and_return([ place, another_place ])
      get :search, :q => place.name, :format => :json
      expect(response.content_type).to eq "application/json"
      json = JSON.parse(response.body)
      expect(json.count).to eq 2
      json.first['html'] == place.html
    end
  end

  describe "merge" do
    let(:keeper) { make_place_with_geom(place_type: Place::STATE) }
    let(:reject) { make_place_with_geom(place_type: Place::COUNTRY) }
    before do
      sign_in make_curator
    end
    it "should delete the reject" do
      reject_id = reject.id
      post :merge, id: reject.slug, with: keeper.id
      log_timer do
        expect(Place.find_by_id(reject_id)).to be_blank
      end
    end
    it "should allow you to keep the reject name" do
      reject_name = reject.name
      post :merge, id: reject.slug, with: keeper.id, keep_name: 'left'
      keeper.reload
      expect(keeper.name).to eq reject_name
    end
    it "should allow you to keep the reject place type" do
      reject_place_type = reject.place_type
      post :merge, id: reject.slug, with: keeper.id, keep_place_type_name: 'left'
      keeper.reload
      expect(keeper.place_type).to eq reject_place_type
    end
  end
end

describe PlacesController, "geometry" do
  before do
    @place = make_place_with_geom(:user => @user)
    @place_without_geom = Place.make!
  end

  it "should return geojson when places have a geometry" do
    get :geometry, format: :geojson, id: @place.id
    expect( response.body ).to include "MultiPolygon"
  end

  it "should not fail when places have no geometry" do
    expect {
      get :geometry, format: :geojson, id: @place_without_geom.id
    }.to_not raise_error
    expect( response.body ).to eq("{}")
  end

# If you ever figure out how to test page caching...
#   # http://pivotallabs.com/tdd-action-caching-in-rails-3/
#   around do |example|
#     caching, ActionController::Base.perform_caching = ActionController::Base.perform_caching, true
#     store, ActionController::Base.cache_store = ActionController::Base.cache_store, :memory_store
#     silence_warnings { Object.const_set "RAILS_CACHE", ActionController::Base.cache_store }
#     example.run
#     silence_warnings { Object.const_set "RAILS_CACHE", store }
#     ActionController::Base.cache_store = store
#     ActionController::Base.perform_caching = caching
#   end

#   it "should page cache kml" do
#     puts "ActionController::Base.perform_caching: #{ActionController::Base.perform_caching}"
#     puts "PlacesController.perform_caching: #{PlacesController.perform_caching}"
#     puts "ActionController::Base.cache_store: #{ActionController::Base.cache_store}"
#     puts "PlacesController.cache_store: #{PlacesController.cache_store}"
#     get :geometry, :id => @place.id, :format => :kml
#     response.should be_page_cached
#     get :geometry, :id => @place.slug, :format => :kml
#     response.should be_page_cached
#   end
end

# describe PlacesController, "update" do
#   before do
#     @user = User.make!
#     sign_in @user
#     @place = make_place_with_geom(:user => @user)
#   end

#   # http://pivotallabs.com/tdd-action-caching-in-rails-3/
#   around do |example|
#     caching, ActionController::Base.perform_caching = ActionController::Base.perform_caching, true
#     store, ActionController::Base.cache_store = ActionController::Base.cache_store, :memory_store
#     silence_warnings { Object.const_set "RAILS_CACHE", ActionController::Base.cache_store }
#     example.run
#     silence_warnings { Object.const_set "RAILS_CACHE", store }
#     ActionController::Base.cache_store = store
#     ActionController::Base.perform_caching = caching
#   end

#   it "should expire geometry kml page cache if geom changed" do
#     get :geometry, :id => @place.id, :format => :kml
#     response.should be_page_cached
    
#     get :geometry, :id => @place.slug, :format => :kml
#     response.should be_page_cached

#     kml = <<-KML
#       <Polygon>
#         <outerBoundaryIs>
#           <LinearRing>
#             <coordinates>
#               -122.42399,37.716570000000004
#               -122.42261,37.71694
#               -122.42094000000002,37.71705
#               -122.42149,37.71838
#               -122.42247,37.717830000000006
#               -122.42324,37.71833
#               -122.42399,37.716570000000004
#             </coordinates>
#           </LinearRing>
#         </outerBoundaryIs>
#       </Polygon>
#     KML
#     without_delay do
#       put :update, :id => @place.id, :kml => kml
#     end
#     response.should be_redirect
#     get :geometry, :id => @place.id, :format => :kml
#     response.should_not be_page_cached
#     get :geometry, :id => @place.slug, :format => :kml
#     response.should_not be_page_cached
#   end
# end

def test_place_geojson(size = :default)
  coords = if size == :default
    [[ [0,0], [0,1], [1,1], [1,0], [0,0] ]]
  elsif size == :huge
    [[ [0,0], [0,60], [60,60], [60,0], [0,0] ]]
  end
  {
    type: "FeatureCollection",
    features: [{
      type: "Feature",
      properties: { },
      geometry: {
        type: "Polygon",
        coordinates: coords
      }
    }]
  }.to_json
end