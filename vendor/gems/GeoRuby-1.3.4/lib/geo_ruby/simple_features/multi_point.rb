require 'geo_ruby/simple_features/geometry_collection'

module GeoRuby
  module SimpleFeatures
    #Represents a group of points (see Point).
    class MultiPoint < GeometryCollection
      
      def initialize(srid= DEFAULT_SRID,with_z=false,with_m=false)
        super(srid,with_z,with_m)
      end
            
      def binary_geometry_type #:nodoc:
        4
      end

      #Text representation of a MultiPoint
      def text_representation(allow_z=true,allow_m=true) #:nodoc:
        "(" + @geometries.collect{|point| point.text_representation(allow_z,allow_m)}.join("),(") + ")"
      end
      #WKT geoemtry type
      def text_geometry_type #:nodoc:
        "MULTIPOINT"
      end

      #Creates a new multi point from an array of points
      def self.from_points(points,srid= DEFAULT_SRID,with_z=false,with_m=false)
        multi_point= new(srid,with_z,with_m)
        multi_point.concat(points)
        multi_point
      end

      #Creates a new multi point from a list of point coordinates : ((x,y)...(x,y))
      def self.from_coordinates(points,srid= DEFAULT_SRID,with_z=false,with_m=false)
        multi_point= new(srid,with_z,with_m)
        multi_point.concat(points.collect {|point| Point.from_coordinates(point,srid,with_z,with_m)})
        multi_point
      end
      
    end
  end
end
