require 'geo_ruby/simple_features/point'
require 'geo_ruby/simple_features/line_string'
require 'geo_ruby/simple_features/linear_ring'
require 'geo_ruby/simple_features/polygon'
require 'geo_ruby/simple_features/multi_point'
require 'geo_ruby/simple_features/multi_line_string'
require 'geo_ruby/simple_features/multi_polygon'
require 'geo_ruby/simple_features/geometry_collection'

module GeoRuby
  module SimpleFeatures

    #Raised when an error in the EWKB string is detected
    class EWKBFormatError < StandardError
    end

    #Parses EWKB strings and notifies of events (such as the beginning of the definition of geometry, the value of the SRID...) the factory passed as argument to the constructor.
    #
    #=Example
    # factory = GeometryFactory::new
    # ewkb_parser = EWKBParser::new(factory)
    # ewkb_parser.parse(<EWKB String>)
    # geometry = @factory.geometry
    #
    #You can also use directly the static method Geometry.from_ewkb
    class EWKBParser
  
      def initialize(factory)
        @factory = factory
        @parse_options ={
          1 => method(:parse_point),
          2 => method(:parse_line_string),
          3 => method(:parse_polygon),
          4 => method(:parse_multi_point),
          5 => method(:parse_multi_line_string),
          6 => method(:parse_multi_polygon),
          7 => method(:parse_geometry_collection)
        }
      end
      
      #Parses the ewkb string passed as argument and notifies the factory of events
      def parse(ewkb)
        @factory.reset
        @unpack_structure=UnpackStructure::new(ewkb)
        @with_z = false
        @with_m = false
        parse_geometry
        @unpack_structure.done
        @srid=nil
      end
      
      private
      def parse_geometry
        @unpack_structure.endianness=@unpack_structure.read_byte
        @geometry_type = @unpack_structure.read_uint
                
        if (@geometry_type & Z_MASK) != 0
          @with_z=true
          @geometry_type = @geometry_type & ~Z_MASK
        end
        if (@geometry_type & M_MASK) != 0
          @with_m=true
          @geometry_type = @geometry_type & ~M_MASK
        end
        if (@geometry_type & SRID_MASK) != 0
          @srid = @unpack_structure.read_uint
          @geometry_type = @geometry_type & ~SRID_MASK
        else
          #to manage multi geometries : the srid is not present in sub_geometries, therefore we take the srid of the parent ; if it is the root, we take the default srid
          @srid= @srid || DEFAULT_SRID
        end
        
        if @parse_options.has_key? @geometry_type
          @parse_options[@geometry_type].call
        else
          raise EWKBFormatError::new("Unknown geometry type")
        end
      end
      
      def parse_geometry_collection
        parse_multi_geometries(GeometryCollection)
      end
      
      def parse_multi_polygon
        parse_multi_geometries(MultiPolygon)
      end
      
      def parse_multi_line_string
        parse_multi_geometries(MultiLineString)
      end
      
      def parse_multi_point
        parse_multi_geometries(MultiPoint)
      end
      
      def parse_multi_geometries(geometry_type)
        @factory.begin_geometry(geometry_type,@srid)
        num_geometries = @unpack_structure.read_uint
        1.upto(num_geometries) { parse_geometry }
        @factory.end_geometry(@with_z,@with_m)
      end
      
      def parse_polygon
        @factory.begin_geometry(Polygon,@srid)
        num_linear_rings = @unpack_structure.read_uint
        1.upto(num_linear_rings) {parse_linear_ring}
        @factory.end_geometry(@with_z,@with_m)
      end
      
      def parse_linear_ring
        parse_point_list(LinearRing)
      end
      
      def parse_line_string
        parse_point_list(LineString)
      end
      
      #used to parse line_strings and linear_rings
      def parse_point_list(geometry_type)
        @factory.begin_geometry(geometry_type,@srid)
        num_points = @unpack_structure.read_uint
        1.upto(num_points) {parse_point}
        @factory.end_geometry(@with_z,@with_m)
      end
      
      def parse_point
        @factory.begin_geometry(Point,@srid)
        x = @unpack_structure.read_double
        y = @unpack_structure.read_double
        if ! (@with_z or @with_m) #most common case probably
          @factory.add_point_x_y(x,y)
        elsif @with_m and @with_z
          z = @unpack_structure.read_double
          m = @unpack_structure.read_double
          @factory.add_point_x_y_z_m(x,y,z,m)
        elsif @with_z
          z = @unpack_structure.read_double
          @factory.add_point_x_y_z(x,y,z)
        else
          m = @unpack_structure.read_double
          @factory.add_point_x_y_m(x,y,m)
        end
                
        @factory.end_geometry(@with_z,@with_m)
      end
    end

    #Parses HexEWKB strings. In reality, it just transforms the HexEWKB string into the equivalent EWKB string and lets the EWKBParser do the actual parsing.
    class HexEWKBParser < EWKBParser
      def initialize(factory)
        super(factory)
      end
      #parses an HexEWKB string
      def parse(hexewkb)
        super(decode_hex(hexewkb))
      end
      #transforms a HexEWKB string into an EWKB string 
      def decode_hex(hexewkb)
        result=""
        num_bytes = (hexewkb.size + 1) / 2
        0.upto(num_bytes-1) do |i|
          result << hexewkb[i*2,2].hex
        end
        result
      end
    end

    class HexEWKBParser < EWKBParser
     #transforms a HexEWKB string into an EWKB string
     # Patched for speedup
     
   end

    class UnpackStructure #:nodoc:
      NDR=1
      XDR=0
      def initialize(ewkb)
        @position=0
        @ewkb=ewkb
      end
      def done
        raise EWKBFormatError::new("Trailing data") if @position != @ewkb.length
      end
      def read_double
        i=@position
        @position += 8
        packed_double = @ewkb[i...@position]
        raise EWKBFormatError::new("Truncated data") if packed_double.nil? or packed_double.length < 8
        packed_double.unpack(@double_mark)[0]
      end
      def read_uint
        i=@position
        @position += 4
        packed_uint = @ewkb[i...@position]
        raise EWKBFormatError::new("Truncated data") if packed_uint.nil? or packed_uint.length < 4
        packed_uint.unpack(@uint_mark)[0]
      end
      def read_byte
        i = @position
        @position += 1
        packed_byte = @ewkb[i...@position]
        raise EWKBFormatError::new("Truncated data") if packed_byte.nil? or packed_byte.length < 1
        packed_byte.unpack("C")[0]
      end
      def endianness=(byte_order)
        if(byte_order == NDR)
          @uint_mark="V"
          @double_mark="E"
        elsif(byte_order == XDR)
          @uint_mark="N"
          @double_mark="G"
        end
      end
    end
  end
end
