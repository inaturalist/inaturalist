require 'geo_ruby/simple_features/geometry'

module GeoRuby
  module SimpleFeatures
    #Represents a collection of arbitrary geometries
    class GeometryCollection < Geometry
      attr_reader :geometries

      def initialize(srid = DEFAULT_SRID,with_z=false,with_m=false)
        super(srid,with_z,with_m)
        @geometries = []
      end
      
      #Delegate the unknown methods to the geometries array
      def method_missing(method_name,*args,&b)
        @geometries.send(method_name,*args,&b)
      end

      #Bounding box in 2D/3D. Returns an array of 2 points
      def bounding_box
        max_x, min_x, max_y, min_y = -Float::MAX, Float::MAX, -Float::MAX, Float::MAX, -Float::MAX, Float::MAX 
        if with_z
          max_z, min_z = -Float::MAX, Float::MAX
          each do |geometry|
            bbox = geometry.bounding_box
            sw = bbox[0]
            ne = bbox[1]
            
            max_y = ne.y if ne.y > max_y
            min_y = sw.y if sw.y < min_y
            max_x = ne.x if ne.x > max_x
            min_x = sw.x if sw.x < min_x 
            max_z = ne.z if ne.z > max_z
            min_z = sw.z if sw.z < min_z 
          end
          [Point.from_x_y_z(min_x,min_y,min_z),Point.from_x_y_z(max_x,max_y,max_z)]
        else
          each do |geometry|
            bbox = geometry.bounding_box
            sw = bbox[0]
            ne = bbox[1]
            
            max_y = ne.y if ne.y > max_y
            min_y = sw.y if sw.y < min_y
            max_x = ne.x if ne.x > max_x
            min_x = sw.x if sw.x < min_x 
          end
          [Point.from_x_y(min_x,min_y),Point.from_x_y(max_x,max_y)]
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

      #tests the equality of geometry collections
      def ==(other_collection)
        if(other_collection.class != self.class)
          false
        elsif length != other_collection.length
          false
        else
          index=0
          while index<length
            return false if self[index] != other_collection[index]
            index+=1
          end
          true
        end
      end
      
      #Binary representation of the collection
      def binary_representation(allow_z=true,allow_m=true) #:nodoc:
        rep = [length].pack("V")
        #output the list of geometries without outputting the SRID first and with the same setting regarding Z and M
        each {|geometry| rep << geometry.as_ewkb(false,allow_z,allow_m) }
        rep
      end
      
      #WKB geometry type of the collection
      def binary_geometry_type #:nodoc:
        7
      end

      #Text representation of a geometry collection
      def text_representation(allow_z=true,allow_m=true) #:nodoc:
        @geometries.collect{|geometry| geometry.as_ewkt(false,allow_z,allow_m)}.join(",")
      end
      
      #WKT geometry type
      def text_geometry_type #:nodoc:
        "GEOMETRYCOLLECTION"
      end

      #georss simple representation : outputs only the first geometry of the collection
      def georss_simple_representation(options)#:nodoc: 
        self[0].georss_simple_representation(options)
      end
      #georss w3c representation : outputs the first point of the outer ring
      def georss_w3cgeo_representation(options)#:nodoc: 
        self[0].georss_w3cgeo_representation(options)
      end
      #georss gml representation : outputs only the first geometry of the collection
      def georss_gml_representation(options)#:nodoc: 
        self[0].georss_gml_representation(options)
      end

      #outputs the geometry in kml format
      def kml_representation(options = {}) #:nodoc: 
        result = "<MultiGeometry#{options[:id_attr]}>\n"
        options[:id_attr] = "" #the subgeometries do not have an ID
        each do |geometry|
          result += geometry.kml_representation(options)
        end
        result += "</MultiGeometry>\n"
      end
      
      #creates a new GeometryCollection from an array of geometries
      def self.from_geometries(geometries,srid=DEFAULT_SRID,with_z=false,with_m=false)
        geometry_collection = new(srid,with_z,with_m)
        geometry_collection.concat(geometries)
        geometry_collection
      end
    end
  end
end
