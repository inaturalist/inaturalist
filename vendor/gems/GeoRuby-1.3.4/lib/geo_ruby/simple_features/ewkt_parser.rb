require 'geo_ruby/simple_features/point'
require 'geo_ruby/simple_features/line_string'
require 'geo_ruby/simple_features/linear_ring'
require 'geo_ruby/simple_features/polygon'
require 'geo_ruby/simple_features/multi_point'
require 'geo_ruby/simple_features/multi_line_string'
require 'geo_ruby/simple_features/multi_polygon'
require 'geo_ruby/simple_features/geometry_collection'

require 'strscan'

module GeoRuby
  module SimpleFeatures

    #Raised when an error in the EWKT string is detected
    class EWKTFormatError < StandardError
    end

    #Parses EWKT strings and notifies of events (such as the beginning of the definition of geometry, the value of the SRID...) the factory passed as argument to the constructor.
    #
    #=Example
    # factory = GeometryFactory::new
    # ewkt_parser = EWKTParser::new(factory)
    # ewkt_parser.parse(<EWKT String>)
    # geometry = @factory.geometry
    #
    #You can also use directly the static method Geometry.from_ewkt
    class EWKTParser
  
      def initialize(factory)
        @factory = factory
        @parse_options ={
          "POINT" => method(:parse_point),
          "LINESTRING" => method(:parse_line_string),
          "POLYGON" => method(:parse_polygon),
          "MULTIPOINT" => method(:parse_multi_point),
          "MULTILINESTRING" => method(:parse_multi_line_string),
          "MULTIPOLYGON" => method(:parse_multi_polygon),
          "GEOMETRYCOLLECTION" => method(:parse_geometry_collection)
        }
      end
      
      #Parses the ewkt string passed as argument and notifies the factory of events
      def parse(ewkt)
        @factory.reset
        @tokenizer_structure = TokenizerStructure.new(ewkt)
        @with_z=false
        @with_m=false
        @is_3dm = false
        parse_geometry(true)
        @srid=nil
      end
      
      private
      def parse_geometry(srid_allowed)
        
        token = @tokenizer_structure.get_next_token
        if token == 'SRID'
          #SRID present
          raise  EWKTFormatError.new("SRID not allowed at this position") if(!srid_allowed)
          if @tokenizer_structure.get_next_token != '='
            raise EWKTFormatError.new("Invalid SRID expression")
          else
            @srid = @tokenizer_structure.get_next_token.to_i
            raise EWKTFormatError.new("Invalid SRID separator") if @tokenizer_structure.get_next_token != ';'
            geom_type = @tokenizer_structure.get_next_token
          end
          
        else
          #to manage multi geometries : the srid is not present in sub_geometries, therefore we take the srid of the parent ; if it is the root, we take the default srid
          @srid= @srid || DEFAULT_SRID
          geom_type = token
        end
        
        if geom_type[-1] == ?M
          @is_3dm=true
          @with_m=true
          geom_type.chop! #remove the M
        end
        
        if @parse_options.has_key?(geom_type)
          @parse_options[geom_type].call
        else
          raise EWKTFormatError.new("Urecognized geometry type: #{geom_type}")
        end
      end
      
      def parse_geometry_collection
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid GeometryCollection')
        end
        
        @factory.begin_geometry(GeometryCollection,@srid)
        
        token = ''
        while token != ')'
          parse_geometry(false)
          token = @tokenizer_structure.get_next_token
          if token.nil?
            raise EWKTFormatError.new("EWKT string not correctly terminated")
          end
        end
        
        @factory.end_geometry(@with_z,@with_m)
      end
      
      def parse_multi_polygon
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid MultiLineString')
        end
        
        @factory.begin_geometry(MultiPolygon,@srid)
        token = ''
        while token != ')'
          parse_polygon
          token = @tokenizer_structure.get_next_token
          if token.nil?
            raise EWKTFormatError.new("EWKT string not correctly terminated")
          end
        end
        
        @factory.end_geometry(@with_z,@with_m)
      end
                 
      def parse_multi_line_string
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid MultiLineString')
        end
        
        @factory.begin_geometry(MultiLineString,@srid)

        token = ''
        while token != ')'
          parse_line_string
          token = @tokenizer_structure.get_next_token
          if token.nil?
            raise EWKTFormatError.new("EWKT string not correctly terminated")
          end
        end
        
        @factory.end_geometry(@with_z,@with_m)
      end

      def parse_polygon
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid Polygon')
        end
        
        @factory.begin_geometry(Polygon,@srid)
        
        token = ''
        while token != ')'
          parse_linear_ring
          token = @tokenizer_structure.get_next_token
          if token.nil?
            raise EWKTFormatError.new("EWKT string not correctly terminated")
          end
        end

        @factory.end_geometry(@with_z,@with_m)
      end
           
      #must support the PostGIS form and the one in the specification
      def parse_multi_point
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid MultiPoint')
        end
        
        token = @tokenizer_structure.check_next_token
        if token == '('
          #specification
          @factory.begin_geometry(MultiPoint,@srid)
                    
          token = ''
          while token != ')'
            parse_point
            token = @tokenizer_structure.get_next_token
            if token.nil?
              raise EWKTFormatError.new("EWKT string not correctly terminated")
            end
          end
                    
          @factory.end_geometry(@with_z,@with_m)
        else
          #postgis
          parse_point_list(MultiPoint)
        end
      end
      
      def parse_linear_ring
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid Linear ring')
        end
        
        parse_point_list(LinearRing)
      end
      
      def parse_line_string
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid Line string')
        end
        
        parse_point_list(LineString)
      end
      
      #used to parse line_strings and linear_rings and the PostGIS form of multi_points
      def parse_point_list(geometry_type)
        @factory.begin_geometry(geometry_type,@srid)
               
        token = ''
        while token != ')'
          @factory.begin_geometry(Point,@srid)
          token = parse_coords
          if token.nil?
            raise EWKTFormatError.new("EWKT string not correctly terminated")
          end
          @factory.end_geometry(@with_z,@with_m)
        end
        
        @factory.end_geometry(@with_z,@with_m)
      end
      
      def parse_point
        if @tokenizer_structure.get_next_token !='('
          raise EWKTFormatError.new('Invalid Point')
        end
        
        @factory.begin_geometry(Point,@srid)
                
        token = parse_coords
        
        if token != ')'
          raise EWKTFormatError.new("EWKT string not correctly terminated")
        end

        @factory.end_geometry(@with_z,@with_m)
      end

      def parse_coords
        coords = Array.new
        x = @tokenizer_structure.get_next_token
        y = @tokenizer_structure.get_next_token

        if x.nil? or y.nil?
          raise EWKTFormatError.new("Bad Point format")
        end
        
        if @is_3dm
          m = @tokenizer_structure.get_next_token

          if m.nil? or m == ',' or m == ')'
            raise EWKTFormatError.new("No M dimension found")
          else
            @factory.add_point_x_y_m(x.to_f,y.to_f,m.to_f)
            @tokenizer_structure.get_next_token
          end
        else
          z = @tokenizer_structure.get_next_token
          
          if z.nil?
            raise EWKTFormatError.new("EWKT string not correctly terminated")
          end
          
          if z == ',' or z == ')'
            #2D : no z no m
            @factory.add_point_x_y(x.to_f,y.to_f)
            z
          else
            m = @tokenizer_structure.get_next_token
            if m.nil?
              raise EWKTFormatError.new("EWKT string not correctly terminated")
            end
            
            if m == ',' or m ==')'
              #3Dz : no m
              @with_z = true
              @factory.add_point_x_y_z(x.to_f,y.to_f,z.to_f)
              m
            else
              #4D
              @with_z = true
              @with_m = true
              @factory.add_point_x_y_z_m(x.to_f,y.to_f,z.to_f,m.to_f)
              @tokenizer_structure.get_next_token
            end
          end
        end
      end
    end
    
    class TokenizerStructure
      
      def initialize(ewkt)
        @ewkt = ewkt
        @scanner = StringScanner.new(ewkt)
        @regex = /\s*([\w.-]+)s*/
      end

      def get_next_token
        if @scanner.scan(@regex).nil?
          if @scanner.eos?
            nil
          else
            ch = @scanner.getch
            while ch == ' '
              ch = @scanner.getch
            end
            ch
          end
        else
          @scanner[1]
        end
      end
      
      
      def check_next_token
        check = @scanner.check(@regex)
        if check.nil?
          if @scanner.eos?
            nil
          else
            pos = @scanner.pos
            while @ewkt[pos].chr == ' '
              pos+=1
            end
            @ewkt[pos].chr
          end
        else
          check
        end
      end

    end

  end
end
