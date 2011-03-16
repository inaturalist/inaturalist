require File.dirname(__FILE__) + '/../spec_helper'

describe PlacesController do
  describe "create" do
    it "should make a place with no default type" do
      user = User.make
      login_as user
      lambda {
        post :create, :place => {
          :name => "Pine Island Ridge Natural Area", 
          :latitude => 26.08, 
          :longitude => -80.27}
      }.should change(Place, :count).by(1)
      Place.last.place_type.should be_blank
    end
  end
end