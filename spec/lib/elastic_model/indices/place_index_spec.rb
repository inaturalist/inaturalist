require "spec_helper"

describe "Place Index" do
  describe "as_indexed_json" do
    it "should return a hash" do
      p = Place.make!
      json = p.as_indexed_json
      expect( json ).to be_a Hash
    end
  end
  describe "geometry indexing" do
    before(:each) { enable_elastic_indexing( Place ) }
    after(:each) { disable_elastic_indexing( Place ) }
    it "should not receive a geometry with duplicate points" do
      wkt = <<-WKT
        MULTIPOLYGON(
          (
            (
              0 0,
              0 0.000001,
              0 0.000001,
              0.000001 0.000001,
              0.000001 0,
              0 0
            )
          )
        )
      WKT
      p = make_place_with_geom( wkt: wkt.gsub( /\s+/, " " ) )
      p.reload
      expect { p.__elasticsearch__.index_document }.not_to raise_error
      Place.__elasticsearch__.refresh_index!
    end
  end
end
