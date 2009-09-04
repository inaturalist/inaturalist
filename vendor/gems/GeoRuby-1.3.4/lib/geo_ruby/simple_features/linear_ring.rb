require 'geo_ruby/simple_features/line_string'

module GeoRuby
  module SimpleFeatures
    #Represents a linear ring, which is a closed line string (see LineString). Currently, no check is performed to verify if the linear ring is really closed.
    class LinearRing < LineString
      def initialize(srid= DEFAULT_SRID,with_z=false,with_m=false)
        super(srid,with_z,with_m)
      end
    end
  end
end
