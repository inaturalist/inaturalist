require "spec_helper"

describe "Place Index" do
  describe "as_indexed_json" do
    it "should return a hash" do
      p = Place.make!
      json = p.as_indexed_json
      expect( json ).to be_a Hash
    end
    it "should set observations_count" do
      expect( make_place_with_geom.as_indexed_json[:observations_count] ).not_to be_nil
    end
  end
end
