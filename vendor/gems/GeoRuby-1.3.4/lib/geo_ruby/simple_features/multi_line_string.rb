require 'geo_ruby/simple_features/geometry_collection'

module GeoRuby
  module SimpleFeatures
    #Represents a group of line strings (see LineString).
    class MultiLineString < GeometryCollection
      def initialize(srid = DEFAULT_SRID,with_z=false,with_m=false)
        super(srid)
      end

      def binary_geometry_type #:nodoc:
        5
      end
      
      #Text representation of a multi line string
      def text_representation(allow_z=true,allow_m=true) #:nodoc:
        @geometries.collect{|line_string| "(" + line_string.text_representation(allow_z,allow_m) + ")" }.join(",")
      end
      #WKT geometry type
      def text_geometry_type #:nodoc:
        "MULTILINESTRING"
      end
      
      #Creates a new multi line string from an array of line strings
      def self.from_line_strings(line_strings,srid=DEFAULT_SRID,with_z=false,with_m=false)
        multi_line_string = new(srid,with_z,with_m)
        multi_line_string.concat(line_strings)
        multi_line_string
      end
      
      #Creates a new multi line string from sequences of points : (((x,y)...(x,y)),((x,y)...(x,y)))
      def self.from_coordinates(point_sequences,srid=DEFAULT_SRID,with_z=false,with_m=false)
        multi_line_string = new(srid,with_z,with_m)
        multi_line_string.concat(point_sequences.collect {|points| LineString.from_coordinates(points,srid,with_z,with_m) })
        multi_line_string
      end
    end
  end
end
