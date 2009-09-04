$:.unshift(File.dirname(__FILE__))

require 'test/unit'
require 'common/common_mysql'
require 'models/models_mysql'


class AccessMysqlTest < Test::Unit::TestCase
   
  def test_point
    pt = TablePoint.new(:data => "Test", :geom => Point.from_x_y(1.2,4.5))
    assert(pt.save)
    
    pt = TablePoint.find(:first)
    assert(pt)
    assert_equal("Test",pt.data)
    assert_equal(Point.from_x_y(1.2,4.5),pt.geom)
    
  end

  def test_line_string
    ls = TableLineString.new(:value => 3, :geom => LineString.from_coordinates([[1.4,2.5],[1.5,6.7]]))
    assert(ls.save)
    
    ls = TableLineString.find(:first)
    assert(ls)
    assert_equal(3,ls.value)
    assert_equal(LineString.from_coordinates([[1.4,2.5],[1.5,6.7]]),ls.geom)
    
  end

  def test_polygon
    pg = TablePolygon.new(:geom => Polygon.from_coordinates([[[12.4,-45.3],[45.4,41.6],[4.456,1.0698],[12.4,-45.3]],[[2.4,5.3],[5.4,1.4263],[14.46,1.06],[2.4,5.3]]]))
    assert(pg.save)

    pg = TablePolygon.find(:first)
    assert(pg)
    assert_equal(Polygon.from_coordinates([[[12.4,-45.3],[45.4,41.6],[4.456,1.0698],[12.4,-45.3]],[[2.4,5.3],[5.4,1.4263],[14.46,1.06],[2.4,5.3]]]),pg.geom)
  end

  def test_muti_point
    mp = TableMultiPoint.new(:geom => MultiPoint.from_coordinates([[12.4,-123.3],[-65.1,123.4],[123.55555555,123]]))
    assert(mp.save)

    mp = TableMultiPoint.find(:first)
    assert(mp)
    assert_equal(MultiPoint.from_coordinates([[12.4,-123.3],[-65.1,123.4],[123.55555555,123]]),mp.geom)
  end

  def test_multi_line_string
    ml = TableMultiLineString.new(:geom => MultiLineString.from_line_strings([LineString.from_coordinates([[1.5,45.2],[-54.12312,-0.012]]),LineString.from_coordinates([[1.5,45.2],[-54.12312,-0.012],[45.123,123.3]])]))
    assert(ml.save)

    ml = TableMultiLineString.find(:first)
    assert(ml)
    assert_equal(MultiLineString.from_line_strings([LineString.from_coordinates([[1.5,45.2],[-54.12312,-0.012]]),LineString.from_coordinates([[1.5,45.2],[-54.12312,-0.012],[45.123,123.3]])]),ml.geom)
  end
  
  def test_multi_polygon
    mp = TableMultiPolygon.new( :geom => MultiPolygon.from_polygons([Polygon.from_coordinates([[[12.4,-45.3],[45.4,41.6],[4.456,1.0698],[12.4,-45.3]],[[2.4,5.3],[5.4,1.4263],[14.46,1.06],[2.4,5.3]]]),Polygon.from_coordinates([[[0,0],[4,0],[4,4],[0,4],[0,0]],[[1,1],[3,1],[3,3],[1,3],[1,1]]])]))
    assert(mp.save)

    mp = TableMultiPolygon.find(:first)
    assert(mp)
    assert_equal(MultiPolygon.from_polygons([Polygon.from_coordinates([[[12.4,-45.3],[45.4,41.6],[4.456,1.0698],[12.4,-45.3]],[[2.4,5.3],[5.4,1.4263],[14.46,1.06],[2.4,5.3]]]),Polygon.from_coordinates([[[0,0],[4,0],[4,4],[0,4],[0,0]],[[1,1],[3,1],[3,3],[1,3],[1,1]]])]),mp.geom)
  end

  def test_geometry
    gm = TableGeometry.new(:geom => LineString.from_coordinates([[12.4,-45.3],[45.4,41.6],[4.456,1.0698]]))
    assert(gm.save)

    gm = TableGeometry.find(:first)
    assert(gm)
    assert_equal(LineString.from_coordinates([[12.4,-45.3],[45.4,41.6],[4.456,1.0698]]),gm.geom)
  end

  def test_geometry_collection
    gc = TableGeometryCollection.new(:geom => GeometryCollection.from_geometries([Point.from_x_y(4.67,45.4),LineString.from_coordinates([[5.7,12.45],[67.55,54]])]))
    assert(gc.save)

    gc = TableGeometryCollection.find(:first)
    assert(gc)
    assert_equal(GeometryCollection.from_geometries([Point.from_x_y(4.67,45.4),LineString.from_coordinates([[5.7,12.45],[67.55,54]])]),gc.geom)
  end
  

end
