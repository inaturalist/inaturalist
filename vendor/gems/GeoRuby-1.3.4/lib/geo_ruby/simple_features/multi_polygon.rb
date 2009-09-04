require 'geo_ruby/simple_features/geometry_collection'


module GeoRuby
  module SimpleFeatures
    #Represents a group of polygons (see Polygon).
   class MultiPolygon < GeometryCollection
      def initialize(srid = DEFAULT_SRID,with_z=false,with_m=false)
        super(srid)
      end

      def binary_geometry_type #:nodoc:
        6
      end
      #Text representation of a MultiPolygon
      def text_representation(allow_z=true,allow_m=true) #:nodoc:
        @geometries.collect{|polygon| "(" + polygon.text_representation(allow_z,allow_m) + ")"}.join(",")
      end
      #WKT geometry type
      def text_geometry_type #:nodoc:
        "MULTIPOLYGON"
      end
      
      #Creates a multi polygon from an array of polygons
      def self.from_polygons(polygons,srid=DEFAULT_SRID,with_z=false,with_m=false)
        multi_polygon = new(srid,with_z,with_m)
        multi_polygon.concat(polygons)
        multi_polygon
      end
      #Creates a multi polygon from sequences of points : ((((x,y)...(x,y)),((x,y)...(x,y)),((x,y)...(x,y))) 
      def self.from_coordinates(point_sequence_sequences,srid= DEFAULT_SRID,with_z=false,with_m=false)
        multi_polygon = new(srid,with_z,with_m)
        multi_polygon.concat( point_sequence_sequences.collect {|point_sequences| Polygon.from_coordinates(point_sequences,srid,with_z,with_m) } )
        multi_polygon
      end
    end
  end
end
