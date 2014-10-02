require File.dirname(__FILE__) + '/../spec_helper'

describe PlacesController do
  describe "create" do
    it "should make a place with no default type" do
      user = User.make!
      sign_in user
      lambda {
        post :create, :place => {
          :name => "Pine Island Ridge Natural Area", 
          :latitude => 26.08, 
          :longitude => -80.27}
      }.should change(Place, :count).by(1)
      Place.last.place_type.should be_blank
    end
  end

  describe "destroy" do
    let(:user) { User.make! }
    let(:place) { Place.make!(:user => user) }
    it "should delete the place" do
      sign_in user
      place.should_not be_blank
      lambda {
        delete :destroy, :id => place.id
      }.should change(Place, :count).by(-1)
    end
  end
end

# If you ever figure out how to test page caching...
# describe PlacesController, "geometry" do
#   before do
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
# end

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
