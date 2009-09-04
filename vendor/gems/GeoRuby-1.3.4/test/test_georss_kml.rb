$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'geo_ruby'
require 'test/unit'

include GeoRuby::SimpleFeatures

class TestGeorssKml < Test::Unit::TestCase

  def test_point_creation
    point = Point.from_x_y(3,4)
    
    assert_equal("<georss:point featuretypetag=\"hoyoyo\" elev=\"45.7\">4 3</georss:point>", point.as_georss(:dialect => :simple, :elev => 45.7, :featuretypetag => "hoyoyo").gsub("\n",""))
    assert_equal("<geo:lat>4</geo:lat><geo:long>3</geo:long>",point.as_georss(:dialect => :w3cgeo).gsub("\n",""))
    assert_equal("<georss:where><gml:Point><gml:pos>4 3</gml:pos></gml:Point></georss:where>",point.as_georss(:dialect => :gml).gsub("\n",""))

    assert_equal("<Point id=\"HOYOYO-42\"><coordinates>3,4</coordinates></Point>",point.as_kml(:id => "HOYOYO-42").gsub("\n",""))
  end

  def test_line_string
    ls = LineString.from_points([Point.from_lon_lat_z(12.4,-45.3,56),Point.from_lon_lat_z(45.4,41.6,45)],123,true)

    assert_equal("<georss:line>-45.3 12.4 41.6 45.4</georss:line>",ls.as_georss.gsub("\n",""))
    assert_equal("<geo:lat>-45.3</geo:lat><geo:long>12.4</geo:long>",ls.as_georss(:dialect => :w3cgeo).gsub("\n",""))
    assert_equal("<georss:where><gml:LineString><gml:posList>-45.3 12.4 41.6 45.4</gml:posList></gml:LineString></georss:where>",ls.as_georss(:dialect => :gml).gsub("\n",""))

    assert_equal("<LineString><extrude>1</extrude><altitudeMode>absolute</altitudeMode><coordinates>12.4,-45.3,56 45.4,41.6,45</coordinates></LineString>",ls.as_kml(:extrude => 1, :altitude_mode => "absolute").gsub("\n",""))
  end 

  def test_polygon
     linear_ring1 = LinearRing.from_coordinates([[12.4,-45.3],[45.4,41.6],[4.456,1.0698],[12.4,-45.3]],256) 
    linear_ring2 = LinearRing.from_coordinates([[2.4,5.3],[5.4,1.4263],[14.46,1.06],[2.4,5.3]],256) 
    polygon = Polygon.from_linear_rings([linear_ring1,linear_ring2],256)

    assert_equal("<hoyoyo:polygon>-45.3 12.4 41.6 45.4 1.0698 4.456 -45.3 12.4</hoyoyo:polygon>",polygon.as_georss(:georss_ns => "hoyoyo").gsub("\n",""))
    assert_equal("<bouyoul:lat>-45.3</bouyoul:lat><bouyoul:long>12.4</bouyoul:long>",polygon.as_georss(:dialect => :w3cgeo, :w3cgeo_ns => "bouyoul").gsub("\n",""))
    assert_equal("<georss:where><gml:Polygon><gml:exterior><gml:LinearRing><gml:posList>-45.3 12.4 41.6 45.4 1.0698 4.456 -45.3 12.4</gml:posList></gml:LinearRing></gml:exterior></gml:Polygon></georss:where>",polygon.as_georss(:dialect => :gml).gsub("\n",""))

    assert_equal("<Polygon><outerBoundaryIs><LinearRing><coordinates>12.4,-45.3 45.4,41.6 4.456,1.0698 12.4,-45.3</coordinates></LinearRing></outerBoundaryIs><innerBoundaryIs><LinearRing><coordinates>2.4,5.3 5.4,1.4263 14.46,1.06 2.4,5.3</coordinates></LinearRing></innerBoundaryIs></Polygon>",polygon.as_kml.gsub("\n",""))
  end

  def test_geometry_collection
    gc = GeometryCollection.from_geometries([Point.from_x_y(4.67,45.4,256),LineString.from_coordinates([[5.7,12.45],[67.55,54]],256)],256)
    
    #only the first geometry is output
    assert_equal("<georss:point floor=\"4\">45.4 4.67</georss:point>",gc.as_georss(:dialect => :simple,:floor => 4).gsub("\n",""))
    assert_equal("<geo:lat>45.4</geo:lat><geo:long>4.67</geo:long>",gc.as_georss(:dialect => :w3cgeo).gsub("\n",""))
    assert_equal("<georss:where><gml:Point><gml:pos>45.4 4.67</gml:pos></gml:Point></georss:where>",gc.as_georss(:dialect => :gml).gsub("\n",""))
    
    assert_equal("<MultiGeometry id=\"HOYOYO-42\"><Point><coordinates>4.67,45.4</coordinates></Point><LineString><coordinates>5.7,12.45 67.55,54</coordinates></LineString></MultiGeometry>",gc.as_kml(:id => "HOYOYO-42").gsub("\n",""))
  end

  def test_envelope
    linear_ring1 = LinearRing.from_coordinates([[12.4,-45.3,5],[45.4,41.6,6],[4.456,1.0698,8],[12.4,-45.3,3.5]],256,true) 
    linear_ring2 = LinearRing.from_coordinates([[2.4,5.3,9.0],[5.4,1.4263,-5.4],[14.46,1.06,34],[2.4,5.3,3.14]],256,true) 
    polygon = Polygon.from_linear_rings([linear_ring1,linear_ring2],256,true)
    
    e = polygon.envelope
    
    assert_equal("<georss:box>-45.3 4.456 41.6 45.4</georss:box>",e.as_georss(:dialect => :simple).gsub("\n",""))
    #center
    assert_equal("<geo:lat>-1.85</geo:lat><geo:long>24.928</geo:long>",e.as_georss(:dialect => :w3cgeo).gsub("\n",""))
    assert_equal("<georss:where><gml:Envelope><gml:LowerCorner>-45.3 4.456</gml:LowerCorner><gml:UpperCorner>41.6 45.4</gml:UpperCorner></gml:Envelope></georss:where>",e.as_georss(:dialect => :gml).gsub("\n",""))
    
    assert_equal("<LatLonAltBox><north>41.6</north><south>-45.3</south><east>45.4</east><west>4.456</west><minAltitude>-5.4</minAltitude><maxAltitude>34</maxAltitude></LatLonAltBox>",e.as_kml.gsub("\n",""))
  end

  def test_point_georss_read
    #W3CGeo
    str = "   <geo:lat >12.3</geo:lat >\n\t  <geo:long>   4.56</geo:long> "
    geom = Geometry.from_georss(str)
    assert_equal(geom.class, Point)
    assert_equal(12.3, geom.lat)
    assert_equal(4.56, geom.lon)

    str = " <geo:Point> \n \t  <geo:long>   4.56</geo:long> \n\t  <geo:lat >12.3</geo:lat > </geo:Point>  "
    geom = Geometry.from_georss(str)
    assert_equal(geom.class, Point)
    assert_equal(12.3, geom.lat)
    assert_equal(4.56, geom.lon)

    #gml
    str = " <georss:where> \t\r  <gml:Point  > \t <gml:pos> 4 \t 3 </gml:pos> </gml:Point> </georss:where>"
    geom = Geometry.from_georss(str)
    assert_equal(geom.class, Point)
    assert_equal(4, geom.lat)
    assert_equal(3, geom.lon)


    #simple 
    str = "<georss:point > 4 \r\t  3 \t</georss:point >"
    geom  = Geometry.from_georss(str)
    assert_equal(geom.class, Point)
    assert_equal(4, geom.lat)
    assert_equal(3, geom.lon)
  
    #simple with tags
    str = "<georss:point featuretypetag=\"hoyoyo\"  elev=\"45.7\" \n floor=\"2\" relationshiptag=\"puyopuyo\" radius=\"42\" > 4 \n 3 \t</georss:point >"
    geom,tags = Geometry.from_georss_with_tags(str)
    assert_equal(geom.class, Point)
    assert_equal(4, geom.lat)
    assert_equal(3, geom.lon)
    assert_equal("hoyoyo",tags.featuretypetag)
    assert_equal(45.7,tags.elev)
    assert_equal("puyopuyo",tags.relationshiptag)
    assert_equal(2,tags.floor)
    assert_equal(42,tags.radius)
  end

  def test_line_string_georss_read
    ls = LineString.from_points([Point.from_lon_lat(12.4,-45.3),Point.from_lon_lat(45.4,41.6)])

    str = "<georss:line > -45.3 12.4 \n \r41.6\t 45.4</georss:line>"
    geom  = Geometry.from_georss(str)
    assert_equal(geom.class, LineString)
    assert_equal(ls ,geom)

    str = "<georss:where><gml:LineString><gml:posList>-45.3 12.4 41.6 45.4</gml:posList></gml:LineString></georss:where>"
    geom  = Geometry.from_georss(str)
    assert_equal(geom.class, LineString)
    assert_equal(ls ,geom)

  end

  def test_polygon_georss_read
    linear_ring = LinearRing.from_coordinates([[12.4,-45.3],[45.4,41.6],[4.456,1.0698],[12.4,-45.3]]) 
    polygon = Polygon.from_linear_rings([linear_ring])

    str = "<hoyoyo:polygon featuretypetag=\"42\"  > -45.3 12.4 41.6 \n\r 45.4 1.0698 \r 4.456 -45.3 12.4 </hoyoyo:polygon>"
    geom = Geometry.from_georss(str)
    assert_equal(geom.class, Polygon)
    assert_equal(polygon, geom)

    str = "<georss:where>\r\t \n  <gml:Polygon><gml:exterior>   <gml:LinearRing><gml:posList> -45.3 \n\r 12.4 41.6 \n\t 45.4 1.0698 4.456 -45.3 12.4</gml:posList></gml:LinearRing></gml:exterior></gml:Polygon></georss:where>"
    geom = Geometry.from_georss(str)
    assert_equal(geom.class, Polygon)
    assert_equal(polygon, geom)
  end

  def test_envelope_georss_read
        
    e = Envelope.from_coordinates([[4.456,-45.3],[45.4,41.6]])
    
    str = "<georss:box  >-45.3 4.456 \n41.6 45.4</georss:box>"
    geom = Geometry.from_georss(str)
    assert_equal(geom.class, Envelope)
    assert_equal(e, geom)

    str = "<georss:where><gml:Envelope><gml:lowerCorner>-45.3 \n 4.456</gml:lowerCorner><gml:upperCorner>41.6 \t\n 45.4</gml:upperCorner></gml:Envelope></georss:where>"
    geom = Geometry.from_georss(str)
    assert_equal(geom.class, Envelope)
    assert_equal(e, geom)

  end

  def test_kml_read
    g = Geometry.from_kml("<Point><coordinates>45,12,25</coordinates></Point>")
    assert(g.is_a?(Point))
    assert_equal(g,Point.from_x_y_z(45,12,25))
    
    g = Geometry.from_kml("<LineString>
      <extrude>1</extrude>
      <tessellate>1</tessellate>
      <coordinates>
        -122.364383,37.824664,0 -122.364152,37.824322,0 
      </coordinates>
    </LineString>")
    assert(g.is_a?(LineString))
    assert(2,g.length)
    assert_equal(LineString.from_points([Point.from_x_y_z(-122.364383,37.824664,0),Point.from_x_y_z(-122.364152,37.824322,0)],DEFAULT_SRID,true),g)
                          
    g = Geometry.from_kml("<Polygon>
      <extrude>1</extrude>
      <altitudeMode>relativeToGround</altitudeMode>
      <outerBoundaryIs>
        <LinearRing>
          <coordinates>
            -122.366278,37.818844,30
            -122.365248,37.819267,30
            -122.365640,37.819861,30
            -122.366669,37.819429,30
            -122.366278,37.818844,30
          </coordinates>
        </LinearRing>
      </outerBoundaryIs>
      <innerBoundaryIs>
        <LinearRing>
          <coordinates>
            -122.366212,37.818977,30
            -122.365424,37.819294,30
            -122.365704,37.819731,30
            -122.366488,37.819402,30
            -122.366212,37.818977,30
          </coordinates>
        </LinearRing>
      </innerBoundaryIs>
      <innerBoundaryIs>
        <LinearRing>
          <coordinates>
            -122.366212,37.818977,30
            -122.365424,37.819294,30
            -122.365704,37.819731,30
            -122.366488,37.819402,30
            -122.366212,37.818977,30
          </coordinates>
        </LinearRing>
      </innerBoundaryIs>
    </Polygon>")
    assert(g.is_a?(Polygon))
    assert_equal(3,g.length)

  end

   def test_to_kml_for_point_does_not_raise_type_error_if_geom_data_not_provided
    point = Point.from_coordinates([1.6,2.8],123)
    assert_nothing_raised(TypeError) { point.kml_representation }
  end
  
  def test_to_kml_for_polygon_does_not_raise_type_error_if_geom_data_not_provided
    polygon =  Polygon.from_coordinates([[[12.4,-45.3],[45.4,41.6],[4.456,1.0698],[12.4,-45.3]],[[2.4,5.3],[5.4,1.4263],[14.46,1.06],[2.4,5.3]]],256)
    
    assert_nothing_raised(TypeError) { polygon.kml_representation }
  end
  
  def test_to_kml_for_line_string_does_not_raise_type_error_if_geom_data_not_provided
    ls = LineString.from_coordinates([[5.7,12.45],[67.55,54]],256)
    assert_nothing_raised(TypeError) { ls.kml_representation }
  end


end
