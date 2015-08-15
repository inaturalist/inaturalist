require File.dirname(__FILE__) + '/../spec_helper.rb'

describe PlaceGeometry, "validation" do
  before(:each) do
    @place = Place.make
  end
  it "should be valid with valid geom" do
    pg = PlaceGeometry.new(:place => @place)
    pg.geom = <<-WKT
      MULTIPOLYGON(
        (
          (
            -122.247619628906 37.8547693305679,
            -122.284870147705 37.8490764953623,
            -122.299289703369 37.8909492165781,
            -122.250881195068 37.8970452004104,
            -122.239551544189 37.8719807055375,
            -122.247619628906 37.8547693305679
          )
        )
      )
    WKT
    expect(pg).to be_valid
  end
  
  it "should be invalid with invalid geom" do
    pg = PlaceGeometry.new(:place => @place)
    two_pt_polygon = "MULTIPOLYGON(((-122.24 37.85,-122.28 37.84)))"
    pg.geom = two_pt_polygon
    expect(pg).not_to be_valid
  end

  describe "observations_places" do
    before(:each) { enable_elastic_indexing( Observation, Place ) }
    after(:each) { disable_elastic_indexing( Observation, Place ) }

    it "should generate observations_places after save" do
      p = make_place_with_geom
      o = Observation.make!
      expect(p.observations_places.length).to eq 0
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be false
      o.update_columns(private_geom: "POINT(#{ p.longitude } #{ p.latitude })")
      p.place_geometry.save
      p.reload
      # observations_places are updated in a delayed job, so the count
      # will still be 0 until the DJ queue is processes
      expect(p.observations_places.length).to eq 0
      Delayed::Worker.new.work_off
      p.reload
      expect(p.observations_places.length).to be >= 1
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be true
    end

    it "deletes its observations_places on destroy" do
      p = make_place_with_geom
      o = Observation.make!(latitude: p.latitude, longitude: p.longitude)
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be true
      p.place_geometry.destroy
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be false
    end

    it "should remove observations_places inside old boundary but outside a new boundary" do
      p = make_place_with_geom(wkt: "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))")
      o = Observation.make!(latitude: p.latitude, longitude: p.longitude)
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be true
      p.save_geom(GeoRuby::SimpleFeatures::Geometry.from_ewkt("MULTIPOLYGON(((0 0,0 -1,-1 -1,-1 0,0 0)))"))
      Delayed::Worker.new.work_off
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be false
    end
  end
end
