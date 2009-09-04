$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'geo_ruby'
require 'test/unit'

include GeoRuby::SimpleFeatures
include GeoRuby::Shp4r

class TestShp < Test::Unit::TestCase

  def test_point
    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/point.shp')
    
    assert_equal(2,shpfile.record_count)
    assert_equal(1,shpfile.fields.length)
    assert_equal(ShpType::POINT,shpfile.shp_type)
    field = shpfile.fields[0]
    assert_equal("Hoyoyo",field.name)
    assert_equal("N",field.type)
    
    record1 = shpfile[0]
    assert(record1.geometry.kind_of?(Point))
    assert_in_delta(-90.08375,record1.geometry.x,0.00001)
    assert_in_delta(34.39996,record1.geometry.y,0.00001)
    assert_equal(6,record1.data['Hoyoyo'])
    
    record2 = shpfile[1]
    assert(record1.geometry.kind_of?(Point))
    assert_in_delta(-87.82580,record2.geometry.x,0.00001)
    assert_in_delta(33.36417,record2.geometry.y,0.00001)
    assert_equal(9,record2.data['Hoyoyo'])
    
    shpfile.close
  end

  def test_polyline
    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/polyline.shp')
    
    assert_equal(1,shpfile.record_count)
    assert_equal(1,shpfile.fields.length)
    assert_equal(ShpType::POLYLINE,shpfile.shp_type)
    field = shpfile.fields[0]
    assert_equal("Chipoto",field.name)
    assert_equal("F",field.type)

    record1 = shpfile[0]
    #a SHP polyline can have multiple parts so they are in fact multilinestrings
    assert(record1.geometry.kind_of?(MultiLineString))
    assert_equal(1,record1.geometry.length)
    assert_equal(6,record1.geometry[0].length)
    assert_equal(5.678,record1.data['Chipoto'])

    shpfile.close
  end 

  def test_polygon
    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/polygon.shp')
    
    assert_equal(1,shpfile.record_count)
    assert_equal(1,shpfile.fields.length)
    assert_equal(ShpType::POLYGON,shpfile.shp_type)
    field = shpfile.fields[0]
    assert_equal("Hello",field.name)
    assert_equal("C",field.type)
    
    record1 = shpfile[0]
    #a SHP polygon can have multiple outer loops (although not supported currently) so they are in fact multipolygons
    assert(record1.geometry.kind_of?(MultiPolygon))
    assert_equal(1,record1.geometry.length)
    assert_equal(1,record1.geometry[0].length)
    assert_equal(7,record1.geometry[0][0].length)
    assert_equal("Bouyoul!",record1.data['Hello'])
    
    shpfile.close
  end
end
