require 'geo_ruby/simple_features/geometry'

module GeoRuby
  module SimpleFeatures
    #Represents a polygon as an array of linear rings (see LinearRing). No check is performed regarding the validity of the geometries forming the polygon.
    class Polygon < Geometry
      #the list of rings forming the polygon
      attr_reader :rings
      
      def initialize(srid = DEFAULT_SRID,with_z=false,with_m=false)
        super(srid,with_z,with_m)
        @rings = []
      end
      
      #Delegate the unknown methods to the rings array
      def method_missing(method_name,*args,&b)
        @rings.send(method_name,*args,&b)
      end
      
      #Bounding box in 2D/3D. Returns an array of 2 points
      def bounding_box
        unless with_z
          @rings[0].bounding_box
        else
          result = @rings[0].bounding_box #valid for x and y
          max_z, min_z = result[1].z, result[0].z
          1.upto(size - 1) do |index|
            bbox = @rings[index].bounding_box
            sw = bbox[0]
            ne = bbox[1]
            max_z = ne.z if ne.z > max_z
            min_z = sw.z if sw.z < min_z 
          end
          result[1].z, result[0].z = max_z, min_z
          result
        end
      end
      
      def m_range
        if with_m
          max_m, min_m = -Float::MAX, Float::MAX
          each do |lr|
            lrmr = lr.m_range
            max_m = lrmr[1] if lrmr[1] > max_m
            min_m = lrmr[0] if lrmr[0] < min_m
          end
          [min_m,max_m]
        else
          [0,0]
        end
      end

      #tests for other equality. The SRID is not taken into account.
      def ==(other_polygon)
        if other_polygon.class != self.class or
            length != other_polygon.length
          false
        else
          index=0
          while index<length
            return false if self[index] != other_polygon[index]
            index+=1
          end
          true
        end
      end
      #binary representation of a polygon, without the headers neccessary for a valid WKB string
      def binary_representation(allow_z=true,allow_m=true)
        rep = [length].pack("V")
        each {|linear_ring| rep << linear_ring.binary_representation(allow_z,allow_m)}
        rep
      end
      #WKB geometry type
      def binary_geometry_type
        3
      end
      
      #Text representation of a polygon 
      def text_representation(allow_z=true,allow_m=true)
        @rings.collect{|line_string| "(" + line_string.text_representation(allow_z,allow_m) + ")" }.join(",")
      end
      #WKT geometry type
      def text_geometry_type
        "POLYGON"
      end

      #georss simple representation : outputs only the outer ring
      def georss_simple_representation(options)
        georss_ns = options[:georss_ns] || "georss"
        geom_attr = options[:geom_attr]
        "<#{georss_ns}:polygon#{geom_attr}>" + self[0].georss_poslist + "</#{georss_ns}:polygon>\n"
      end
      #georss w3c representation : outputs the first point of the outer ring
      def georss_w3cgeo_representation(options)
        w3cgeo_ns = options[:w3cgeo_ns] || "geo"
        
        "<#{w3cgeo_ns}:lat>#{self[0][0].y}</#{w3cgeo_ns}:lat>\n<#{w3cgeo_ns}:long>#{self[0][0].x}</#{w3cgeo_ns}:long>\n"
      end
      #georss gml representation
      def georss_gml_representation(options)
        georss_ns = options[:georss_ns] || "georss"
        gml_ns = options[:gml_ns] || "gml"
       
        result = "<#{georss_ns}:where>\n<#{gml_ns}:Polygon>\n<#{gml_ns}:exterior>\n<#{gml_ns}:LinearRing>\n<#{gml_ns}:posList>\n" + self[0].georss_poslist + "\n</#{gml_ns}:posList>\n</#{gml_ns}:LinearRing>\n</#{gml_ns}:exterior>\n</#{gml_ns}:Polygon>\n</#{georss_ns}:where>\n"
      end

      #outputs the geometry in kml format : options are <tt>:id</tt>, <tt>:tesselate</tt>, <tt>:extrude</tt>,
      #<tt>:altitude_mode</tt>. If the altitude_mode option is not present, the Z (if present) will not be output (since
      #it won't be used by GE anyway: clampToGround is the default)
      def kml_representation(options = {})
        result = "<Polygon#{options[:id_attr]}>\n"
        result += options[:geom_data] if options[:geom_data]
        rings.each_with_index do |ring, i|
          if i == 0
            boundary = "outerBoundaryIs"
          else
            boundary = "innerBoundaryIs"
          end
          result += "<#{boundary}><LinearRing><coordinates>\n"
          result += ring.kml_poslist(options)
          result += "\n</coordinates></LinearRing></#{boundary}>\n"
        end
        result += "</Polygon>\n"
      end
    
      #creates a new polygon. Accepts an array of linear strings as argument
      def self.from_linear_rings(linear_rings,srid = DEFAULT_SRID,with_z=false,with_m=false)
        polygon = new(srid,with_z,with_m)
        polygon.concat(linear_rings)
        polygon
      end
      
      #creates a new polygon. Accepts a sequence of points as argument : ((x,y)....(x,y)),((x,y).....(x,y))
      def self.from_coordinates(point_sequences,srid=DEFAULT_SRID,with_z=false,with_m=false)
        polygon = new(srid,with_z,with_m)
        polygon.concat( point_sequences.collect {|points| LinearRing.from_coordinates(points,srid,with_z,with_m) } )
        polygon
      end

      #creates a new polygon from a list of Points (pt1....ptn),(pti....ptj)
      def self.from_points(point_sequences, srid=DEFAULT_SRID,with_z=false,with_m=false)
        polygon = new(srid,with_z,with_m)
        polygon.concat( point_sequences.collect {|points| LinearRing.from_points(points,srid,with_z,with_m) } )
        polygon

      end

    end
  end
end
