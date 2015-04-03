require "spec_helper"

describe ElasticModel do

  before(:all) do
    @taxon = Taxon.make!
    @place = Place.make!
  end

  it "has a hash of analyzers and filters" do
    expect( ElasticModel::ANALYSIS ).to be_a Hash
    expect( ElasticModel::ANALYSIS[:analyzer].count ).to be 5
    expect( ElasticModel::ANALYSIS[:filter].count ).to be 1
  end

  describe "search_criteria" do
    it "returns nil unless given a hash" do
      expect( ElasticModel.search_criteria(:nonsense) ).to be nil
      expect( ElasticModel.search_criteria({ }) ).to eq [ ]
    end

    it "turns wheres into proper matches" do
      expect( ElasticModel.search_criteria(
        where: { "taxon.id": @taxon, "title": "q" }) ).to eq([
          { match: { "taxon.id": @taxon.id } },
          { match: { "title": "q" } } ])
    end

    it "turns array of values into a terms match query" do
      expect( ElasticModel.search_criteria(
        where: { "taxon.id": [ 1, 2 ] }) ).to eq([
          { terms: { "taxon.id": [1, 2] } } ])
    end

    it "accepts complicated wheres verbatim" do
      match = { match: { "names_suggest.name":
        { query: "q", operator: "and" } } }
      expect( ElasticModel.search_criteria(
        where: match ) ).to eq([ match ])
    end

  end

  describe "id_or_object" do
    it "returns an instance's ID" do
      expect( ElasticModel.id_or_object(@taxon) ).to be @taxon.id
    end

    it "returns everything else verbatim" do
      expect( ElasticModel.id_or_object(nil) ).to be nil
      expect( ElasticModel.id_or_object("") ).to eq ""
      expect( ElasticModel.id_or_object({ id: 55 }) ).to eq({ id: 55 })
    end
  end

  describe "place_filter" do
    it "returns nil unless given an options has with a place filter" do
      expect( ElasticModel.place_filter(@place) ).to be nil
      expect( ElasticModel.place_filter({ }) ).to be nil
      expect( ElasticModel.place_filter(
        { place: @place } ) ).to be_a Hash
    end

    it "returns a proper geo_shape filter hash" do
      expect( ElasticModel.place_filter(
        { place: @place } ) ).to eq({
          geo_shape: {
            geojson: {
              indexed_shape: {
                id: @place.id,
                type: "place",
                index: "test_places",
                path: "geometry_geojson" }}}})
    end
  end

  describe "envelope_filter" do
    it "returns nil unless given an options has with some bounds" do
      expect( ElasticModel.envelope_filter({ }) ).to be nil
      expect( ElasticModel.envelope_filter(
        { envelope: { geojson: { nelat: 50 }}})).to be_a Hash
    end

    it "returns a proper envelope filter" do
      expect( ElasticModel.envelope_filter(
        { envelope: { geojson: { nelat: 11, nelng: 12, swlat: 13, swlng: 14 }}})).to eq({
          geo_shape: {
            geojson: {
              shape: {
                type: "envelope",
                coordinates: [[14, 13], [12, 11]] }}}})
    end

    it "defaults bounds to their extreme" do
      expect( ElasticModel.envelope_filter(
        { envelope: { geojson: { nelat: 88 }}})).to eq({
          geo_shape: {
            geojson: {
              shape: {
                type: "envelope",
                coordinates: [[-180, -90], [180, 88]] }}}})
    end
  end

  describe "valid_latlon?" do
    it "returns true when given two integers representing valid lat/lon" do
      expect( ElasticModel.valid_latlon?("0", "0") ).to be false
      expect( ElasticModel.valid_latlon?(100, 0) ).to be false
      expect( ElasticModel.valid_latlon?(-100, 0) ).to be false
      expect( ElasticModel.valid_latlon?(0, 200) ).to be false
      expect( ElasticModel.valid_latlon?(0, -200) ).to be false
      expect( ElasticModel.valid_latlon?(0, 0) ).to be true
    end
  end

  describe "point_geojson" do
    it "returns a valid geojson hash given lat/lon" do
      expect( ElasticModel.point_geojson(1, 2) ).to eq({
        type: "point", coordinates: [2, 1] })
    end
  end

  describe "point_latlon" do
    it "returns a coordinates string lat/lon" do
      expect( ElasticModel.point_latlon(1, 2) ).to eq "1,2"
    end
  end

  describe "geom_geojson" do
    it "returns a multipolygon geojson given a multipolygon" do
      geom = RGeo::Geos::CAPIFactory.new.parse_wkt("MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))")
      expect( ElasticModel.geom_geojson(geom) ).to eq({
        "type" => "MultiPolygon",
        "coordinates" => [[[[0.0, 0.0], [0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0]]]] })
    end

    it "returns a point geojson given a point" do
      geom = RGeo::Geos::CAPIFactory.new.parse_wkt("POINT(1 2)")
      expect( ElasticModel.geom_geojson(geom) ).to eq({
        "type" => "Point",
        "coordinates" => [1.0, 2.0] })
    end
  end

end
