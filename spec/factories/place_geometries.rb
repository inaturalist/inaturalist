FactoryBot.define do
  factory :place_geometry do
    place
    source

    transient { ewkt { "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))" } }
    after :build, :stub do |place_geometry, eval|
      georuby_geom = GeoRuby::SimpleFeatures::Geometry.from_ewkt(eval.ewkt)
      place_geometry.geom = RGeo::WKRep::WKBParser.new.parse(georuby_geom.as_wkb)
    end
  end
end
