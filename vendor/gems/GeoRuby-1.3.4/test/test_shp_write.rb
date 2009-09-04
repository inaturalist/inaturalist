$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'geo_ruby'
require 'test/unit'

include GeoRuby::SimpleFeatures
include GeoRuby::Shp4r

class TestShp < Test::Unit::TestCase
  
  def cp_all_shp(file1,file2)
    FileUtils.copy(file1 + ".shp",file2 + ".shp")
    FileUtils.copy(file1 + ".shx",file2 + ".shx")
    FileUtils.copy(file1 + ".dbf",file2 + ".dbf")
  end

  def rm_all_shp(file)
    FileUtils.rm(file + ".shp")
    FileUtils.rm(file + ".shx")
    FileUtils.rm(file + ".dbf")
  end
  
  def test_point
    cp_all_shp(File.dirname(__FILE__) + '/data/point',
               File.dirname(__FILE__) + '/data/point2')
    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/point2.shp')
    
    shpfile.transaction do |tr|
      assert(tr.instance_of?(ShpTransaction))
      tr.add(ShpRecord.new(Point.from_x_y(123.4,123.4),'Hoyoyo' => 5))
      tr.add(ShpRecord.new(Point.from_x_y(-16.67,16.41),'Hoyoyo' => -7))
      tr.delete(1)
    end
    
    assert_equal(3,shpfile.record_count)
    
    shpfile.close
    rm_all_shp(File.dirname(__FILE__) + '/data/point2')
  end

  def test_linestring
    cp_all_shp(File.dirname(__FILE__) + '/data/polyline',
               File.dirname(__FILE__) + '/data/polyline2')
    
    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/polyline2.shp')
    
    shpfile.transaction do |tr|
      assert(tr.instance_of?(ShpTransaction))
      tr.add(ShpRecord.new(LineString.from_coordinates([[123.4,123.4],[45.6,12.3]]),'Chipoto' => 5.6778))
      tr.add(ShpRecord.new(LineString.from_coordinates([[23.4,13.4],[45.6,12.3],[12,-67]]),'Chipoto' => -7.1))
      tr.delete(0)
    end
    
    assert_equal(2,shpfile.record_count)
    shpfile.close
    rm_all_shp(File.dirname(__FILE__) + '/data/polyline2')
  end

  def test_polygon
    cp_all_shp(File.dirname(__FILE__) + '/data/polygon',
               File.dirname(__FILE__) + '/data/polygon2')
    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/polygon2.shp')

    shpfile.transaction do |tr|
      assert(tr.instance_of?(ShpTransaction))
      tr.delete(0)
      tr.add(ShpRecord.new(Polygon.from_coordinates([[[0,0],[40,0],[40,40],[0,40],[0,0]],[[10,10],[10,20],[20,20],[10,10]]]),'Hello' => "oook"))
    end
        
    assert_equal(1,shpfile.record_count)
    
    shpfile.close
    rm_all_shp(File.dirname(__FILE__) + '/data/polygon2')
  end

  def test_multipoint
    cp_all_shp(File.dirname(__FILE__) + '/data/multipoint',
               File.dirname(__FILE__) + '/data/multipoint2')
    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/multipoint2.shp')

    shpfile.transaction do |tr|
      assert(tr.instance_of?(ShpTransaction))
      tr.add(ShpRecord.new(MultiPoint.from_coordinates([[45.6,-45.1],[12.4,98.2],[51.2,-0.12],[156.12345,56.109]]),'Hello' => 5,"Hoyoyo" => "AEZAE"))
    end
        
    assert_equal(2,shpfile.record_count)
    
    shpfile.close
    rm_all_shp(File.dirname(__FILE__) + '/data/multipoint2')
  end

  def test_multi_polygon
    cp_all_shp(File.dirname(__FILE__) + '/data/polygon',
               File.dirname(__FILE__) + '/data/polygon4')

    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/polygon4.shp')

    shpfile.transaction do |tr|
      assert(tr.instance_of?(ShpTransaction))
      tr.add(ShpRecord.new(MultiPolygon.from_polygons([Polygon.from_coordinates([[[0,0],[40,0],[40,40],[0,40],[0,0]],[[10,10],[10,20],[20,20],[10,10]]])]),'Hello' => "oook"))
    end
        
    assert_equal(2,shpfile.record_count)
    
    shpfile.close
    
    rm_all_shp(File.dirname(__FILE__) + '/data/polygon4')
  end
  
  def test_rollback
    cp_all_shp(File.dirname(__FILE__) + '/data/polygon',
               File.dirname(__FILE__) + '/data/polygon5')

    shpfile = ShpFile.open(File.dirname(__FILE__) + '/data/polygon5.shp')

    shpfile.transaction do |tr|
      assert(tr.instance_of?(ShpTransaction))
      tr.add(ShpRecord.new(MultiPolygon.from_polygons([Polygon.from_coordinates([[[0,0],[40,0],[40,40],[0,40],[0,0]],[[10,10],[10,20],[20,20],[10,10]]])]),'Hello' => "oook"))
      tr.rollback
    end
    assert_equal(1,shpfile.record_count)
    
    shpfile.close
    
    rm_all_shp(File.dirname(__FILE__) + '/data/polygon5')

  end

  def test_creation
    shpfile = ShpFile.create(File.dirname(__FILE__) + '/data/point3.shp',ShpType::POINT,[Dbf::Field.new("Hoyoyo","C",10,0)])
    shpfile.transaction do |tr|
      tr.add(ShpRecord.new(Point.from_x_y(123,123.4),'Hoyoyo' => "HJHJJ"))
    end
    assert(1,shpfile.record_count)
    shpfile.close
    rm_all_shp(File.dirname(__FILE__) + '/data/point3')
  end

  def test_creation_multipoint
    shpfile = ShpFile.create(File.dirname(__FILE__) + '/data/multipoint3.shp',ShpType::MULTIPOINT,[Dbf::Field.new("Hoyoyo","C",10),Dbf::Field.new("Hello","N",10)])
    shpfile.transaction do |tr|
      tr.add(ShpRecord.new(MultiPoint.from_coordinates([[123,123.4],[345,12.2]]),'Hoyoyo' => "HJHJJ","Hello" => 5))
    end
    assert(1,shpfile.record_count)
    shpfile.close
    rm_all_shp(File.dirname(__FILE__) + '/data/multipoint3')
  end
  

end
