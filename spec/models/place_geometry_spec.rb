require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PlaceGeometry, "validation" do
  before(:each) do
    @place = Place.make
  end
  it "should be valid with valid geom" do
    pg = PlaceGeometry.new(:place => @place)
    pg.geom = GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))")
    pg.should be_valid
  end
  
  it "should be invalid with invalid geom" do
    pg = PlaceGeometry.new(:place => @place)
    two_pt_polygon = GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.24 37.85,-122.28 37.84)))")
    pg.geom = two_pt_polygon
    pg.should_not be_valid
  end
end