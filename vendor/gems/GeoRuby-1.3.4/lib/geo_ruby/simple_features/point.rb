require "geo_ruby/simple_features/geometry"

module GeoRuby
  module SimpleFeatures
    #Represents a point. It is in 3D if the Z coordinate is not +nil+.
    class Point < Geometry
            
      attr_accessor :x,:y,:z,:m
      #if you prefer calling the coordinates lat and lon (or lng, for GeoKit compatibility)
      alias :lon :x
      alias :lng :x
      alias :lat :y
      
      def initialize(srid=DEFAULT_SRID,with_z=false,with_m=false)
        super(srid,with_z,with_m)
        @x=0.0
        @y=0.0
        @z=0.0 #default value : meaningful if with_z
        @m=0.0 #default value : meaningful if with_m
      end
      #sets all coordinates in one call. Use the +m+ accessor to set the m.
      def set_x_y_z(x,y,z)
        @x=x
        @y=y
        @z=z
        self
      end
      alias :set_lon_lat_z :set_x_y_z
      
      #sets all coordinates of a 2D point in one call
      def set_x_y(x,y)
        @x=x
        @y=y
        self
      end
      alias :set_lon_lat :set_x_y
      
      #Return the distance between the 2D points (ie taking care only of the x and y coordinates), assuming the points are in projected coordinates. Euclidian distance in whatever unit the x and y ordinates are.
      def euclidian_distance(point)
        Math.sqrt((point.x - x)**2 + (point.y - y)**2)
      end

      #Returns the sperical distance in m, with a radius of 6471000m, with the haversine law. Assumes x is the lon and y the lat, in degrees (Changed in version 1.1). The user has to make sure using this distance makes sense (ie she should be in latlon coordinates)
      def spherical_distance(point,radius=6370997.0)
        deg_to_rad = 0.0174532925199433
        
        radlat_from = lat * deg_to_rad
        radlat_to = point.lat * deg_to_rad
        
        dlat = (point.lat - lat) * deg_to_rad
        dlon = (point.lon - lon) * deg_to_rad
 
        a = Math.sin(dlat/2)**2 + Math.cos(radlat_from) * Math.cos(radlat_to) * Math.sin(dlon/2)**2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
        radius * c
      end

      #Ellipsoidal distance in m using Vincenty's formula. Lifted entirely from Chris Veness's code at http://www.movable-type.co.uk/scripts/LatLongVincenty.html and adapted for Ruby. Assumes the x and y are the lon and lat in degrees.
      #a is the semi-major axis (equatorial radius) of the ellipsoid
      #b is the semi-minor axis (polar radius) of the ellipsoid
      #Their values by default are set to the ones of the WGS84 ellipsoid
      def ellipsoidal_distance(point, a = 6378137.0, b = 6356752.3142)
        deg_to_rad = 0.0174532925199433
        
        f = (a-b) / a
        l = (point.lon - lon) * deg_to_rad
        
        u1 = Math.atan((1-f) * Math.tan(lat * deg_to_rad ))
        u2 = Math.atan((1-f) * Math.tan(point.lat * deg_to_rad))
        sinU1 = Math.sin(u1)
        cosU1 = Math.cos(u1)
        sinU2 = Math.sin(u2)
        cosU2 = Math.cos(u2)
  
        lambda = l
        lambdaP = 2 * Math::PI
        iterLimit = 20
        
        while (lambda-lambdaP).abs > 1e-12 && --iterLimit>0
          sinLambda = Math.sin(lambda)
          cosLambda = Math.cos(lambda)
          sinSigma = Math.sqrt((cosU2*sinLambda) * (cosU2*sinLambda) + (cosU1*sinU2-sinU1*cosU2*cosLambda) * (cosU1*sinU2-sinU1*cosU2*cosLambda))
          
          return 0 if sinSigma == 0 #coincident points
          
          cosSigma = sinU1*sinU2 + cosU1*cosU2*cosLambda
          sigma = Math.atan2(sinSigma, cosSigma)
          sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma
          cosSqAlpha = 1 - sinAlpha*sinAlpha
          cos2SigmaM = cosSigma - 2*sinU1*sinU2/cosSqAlpha
          
          cos2SigmaM = 0 if (cos2SigmaM.nan?) #equatorial line: cosSqAlpha=0

          c = f/16*cosSqAlpha*(4+f*(4-3*cosSqAlpha))
          lambdaP = lambda
          lambda = l + (1-c) * f * sinAlpha * (sigma + c * sinSigma * (cos2SigmaM + c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
        end
        return NaN if iterLimit==0 #formula failed to converge

        uSq = cosSqAlpha * (a*a - b*b) / (b*b)
        a_bis = 1 + uSq/16384*(4096+uSq*(-768+uSq*(320-175*uSq)))
        b_bis = uSq/1024 * (256+uSq*(-128+uSq*(74-47*uSq)))
        deltaSigma = b_bis * sinSigma*(cos2SigmaM + b_bis/4*(cosSigma*(-1+2*cos2SigmaM*cos2SigmaM)- b_bis/6*cos2SigmaM*(-3+4*sinSigma*sinSigma)*(-3+4*cos2SigmaM*cos2SigmaM)))
      
        b*a_bis*(sigma-deltaSigma)
      end

            
      #Bounding box in 2D/3D. Returns an array of 2 points
      def bounding_box
        unless with_z
          [Point.from_x_y(@x,@y),Point.from_x_y(@x,@y)]
        else
          [Point.from_x_y_z(@x,@y,@z),Point.from_x_y_z(@x,@y,@z)]
        end
      end

      def m_range
        [@m,@m]
      end
      
      #tests the equality of the position of points + m
      def ==(other_point)
        if other_point.class != self.class
          false
        else
          @x == other_point.x and @y == other_point.y and @z == other_point.z and @m == other_point.m
        end
      end
      
      #binary representation of a point. It lacks some headers to be a valid EWKB representation.
      def binary_representation(allow_z=true,allow_m=true) #:nodoc:
        bin_rep = [@x,@y].pack("EE")
        bin_rep += [@z].pack("E") if @with_z and allow_z #Default value so no crash
        bin_rep += [@m].pack("E") if @with_m and allow_m #idem
        bin_rep
      end
      #WKB geometry type of a point
      def binary_geometry_type#:nodoc:
        1
      end
      
      #text representation of a point
      def text_representation(allow_z=true,allow_m=true) #:nodoc:
        tex_rep = "#{@x} #{@y}"
        tex_rep += " #{@z}" if @with_z and allow_z
        tex_rep += " #{@m}" if @with_m and allow_m
        tex_rep
      end
      #WKT geometry type of a point
      def text_geometry_type #:nodoc:
        "POINT"
      end

      #georss simple representation
      def georss_simple_representation(options) #:nodoc:
        georss_ns = options[:georss_ns] || "georss"
        geom_attr = options[:geom_attr]
        "<#{georss_ns}:point#{geom_attr}>#{y} #{x}</#{georss_ns}:point>\n"
      end
      #georss w3c representation
      def georss_w3cgeo_representation(options) #:nodoc:
        w3cgeo_ns = options[:w3cgeo_ns] || "geo"
        "<#{w3cgeo_ns}:lat>#{y}</#{w3cgeo_ns}:lat>\n<#{w3cgeo_ns}:long>#{x}</#{w3cgeo_ns}:long>\n"
      end
      #georss gml representation
      def georss_gml_representation(options) #:nodoc:
        georss_ns = options[:georss_ns] || "georss"
        gml_ns = options[:gml_ns] || "gml"
        result = "<#{georss_ns}:where>\n<#{gml_ns}:Point>\n<#{gml_ns}:pos>"
        result += "#{y} #{x}"
        result += "</#{gml_ns}:pos>\n</#{gml_ns}:Point>\n</#{georss_ns}:where>\n"
      end

      #outputs the geometry in kml format : options are <tt>:id</tt>, <tt>:tesselate</tt>, <tt>:extrude</tt>,
      #<tt>:altitude_mode</tt>. If the altitude_mode option is not present, the Z (if present) will not be output (since
      #it won't be used by GE anyway: clampToGround is the default)
      def kml_representation(options = {}) #:nodoc: 
        result = "<Point#{options[:id_attr]}>\n"
        result += options[:geom_data] if options[:geom_data]
        result += "<coordinates>#{x},#{y}"
        result += ",#{options[:fixed_z] || z ||0}" if options[:allow_z]
        result += "</coordinates>\n"
        result += "</Point>\n"
      end
      
      #creates a point from an array of coordinates
      def self.from_coordinates(coords,srid=DEFAULT_SRID,with_z=false,with_m=false)
        if ! (with_z or with_m)
          from_x_y(coords[0],coords[1],srid)
        elsif with_z and with_m
          from_x_y_z_m(coords[0],coords[1],coords[2],coords[3],srid)
        elsif with_z
          from_x_y_z(coords[0],coords[1],coords[2],srid)
        else
          from_x_y_m(coords[0],coords[1],coords[2],srid) 
        end
      end

      #creates a point from the X and Y coordinates
      def self.from_x_y(x,y,srid=DEFAULT_SRID)
        point= new(srid)
        point.set_x_y(x,y)
      end
      
      #creates a point from the X, Y and Z coordinates
      def self.from_x_y_z(x,y,z,srid=DEFAULT_SRID)
        point= new(srid,true)
        point.set_x_y_z(x,y,z)
      end
      

      #creates a point from the X, Y and M coordinates
      def self.from_x_y_m(x,y,m,srid=DEFAULT_SRID)
        point= new(srid,false,true)
        point.m=m
        point.set_x_y(x,y)
      end
      
      #creates a point from the X, Y, Z and M coordinates
      def self.from_x_y_z_m(x,y,z,m,srid=DEFAULT_SRID)
        point= new(srid,true,true)
        point.m=m
        point.set_x_y_z(x,y,z)
      end
      
      #aliasing the constructors in case you want to use lat/lon instead of y/x
      class << self
        alias :from_lon_lat :from_x_y
        alias :from_lon_lat_z :from_x_y_z
        alias :from_lon_lat_m :from_x_y_m
        alias :from_lon_lat_z_m :from_x_y_z_m
      end
    end
  end
end
