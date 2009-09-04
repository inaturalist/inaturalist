require 'geo_ruby/simple_features/point'
require 'geo_ruby/simple_features/line_string'
require 'geo_ruby/simple_features/linear_ring'
require 'geo_ruby/simple_features/polygon'
require 'geo_ruby/simple_features/multi_point'
require 'geo_ruby/simple_features/multi_line_string'
require 'geo_ruby/simple_features/multi_polygon'
require 'geo_ruby/simple_features/geometry_collection'
require 'geo_ruby/simple_features/envelope'

module GeoRuby
  module SimpleFeatures

    #Raised when an error in the GeoRSS string is detected
    class GeorssFormatError < StandardError
    end

    #Contains tags possibly found on GeoRss Simple geometries
    class GeorssTags < Struct.new(:featuretypetag,:relationshiptag,:elev,:floor,:radius)
    end

    #Parses GeoRSS strings
    #You can also use directly the static method Geometry.from_georss
    class GeorssParser
      attr_reader :georss_tags, :geometry
 
      #Parses the georss geometry  passed as argument and notifies the factory of events
      #The parser assumes 
      def parse(georss,with_tags = false)
        @geometry = nil
        @georss_tags = GeorssTags.new
        parse_geometry(georss,with_tags)
      end
      
      private
      def parse_geometry(georss,with_tags)
        georss.strip!
        #check for W3CGeo first
        if georss =~ /<[^:>]*:lat\s*>([^<]*)</
          #if valid, it is W3CGeo
          lat = $1.to_f
          if georss =~ /<[^:>]*:long\s*>([^<]*)</
            lon = $1.to_f
            @geometry = Point.from_x_y(lon,lat)
          else
            raise GeorssFormatError.new("Bad W3CGeo GeoRSS format")
          end
        elsif georss =~ /^<\s*[^:>]*:where\s*>/
          #GML format found
          gml = $'.strip
          if gml =~ /^<\s*[^:>]*:Point\s*>/
            #gml point
            if gml =~ /<\s*[^:>]*:pos\s*>([^<]*)/
              point = $1.split(" ")
              #lat comes first
              @geometry = Point.from_x_y(point[1].to_f,point[0].to_f)
            else
              raise GeorssFormatError.new("Bad GML GeoRSS format: Malformed Point")
            end
          elsif gml =~ /^<\s*[^:>]*:LineString\s*>/
            if gml =~ /<\s*[^:>]*:posList\s*>([^<]*)/
              xy = $1.split(" ")
              @geometry = LineString.new
              0.upto(xy.size/2 - 1) { |index| @geometry << Point.from_x_y(xy[index*2 + 1].to_f,xy[index*2].to_f)}
            else
              raise GeorssFormatError.new("Bad GML GeoRSS format: Malformed LineString")
            end
          elsif gml =~ /^<\s*[^:>]*:Polygon\s*>/
            if gml =~ /<\s*[^:>]*:posList\s*>([^<]*)/
              xy = $1.split(" ")
              @geometry = Polygon.new
              linear_ring = LinearRing.new
              @geometry << linear_ring
              xy = $1.split(" ")
              0.upto(xy.size/2 - 1) { |index| linear_ring << Point.from_x_y(xy[index*2 + 1].to_f,xy[index*2].to_f)}
            else
              raise GeorssFormatError.new("Bad GML GeoRSS format: Malformed Polygon")
            end
          elsif gml =~ /^<\s*[^:>]*:Envelope\s*>/
            if gml =~ /<\s*[^:>]*:lowerCorner\s*>([^<]*)</
              lc = $1.split(" ").collect { |x| x.to_f}.reverse
              if gml =~ /<\s*[^:>]*:upperCorner\s*>([^<]*)</
                uc = $1.split(" ").collect { |x| x.to_f}.reverse
                @geometry = Envelope.from_coordinates([lc,uc])
              else
                raise GeorssFormatError.new("Bad GML GeoRSS format: Malformed Envelope")
              end
            else
              raise GeorssFormatError.new("Bad GML GeoRSS format: Malformed Envelope")
            end
          else
            raise GeorssFormatError.new("Bad GML GeoRSS format: Unknown geometry type")
          end
        else
          #must be simple format
          if georss =~ /^<\s*[^>:]*:point([^>]*)>(.*)</m
            tags = $1
            point = $2.gsub(","," ").split(" ")
            @geometry = Point.from_x_y(point[1].to_f,point[0].to_f)
          elsif georss =~ /^<\s*[^>:]*:line([^>]*)>(.*)</m
            tags = $1
            @geometry = LineString.new
            xy = $2.gsub(","," ").split(" ")
            0.upto(xy.size/2 - 1) { |index| @geometry << Point.from_x_y(xy[index*2 + 1].to_f,xy[index*2].to_f)}
          elsif georss =~ /^<\s*[^>:]*:polygon([^>]*)>(.*)</m
            tags = $1
            @geometry = Polygon.new
            linear_ring = LinearRing.new
            @geometry << linear_ring
            xy = $2.gsub(","," ").split(" ")
            0.upto(xy.size/2 - 1) { |index| linear_ring << Point.from_x_y(xy[index*2 + 1].to_f,xy[index*2].to_f)}
          elsif georss =~ /^<\s*[^>:]*:box([^>]*)>(.*)</m
            tags = $1
            corners = []
            xy = $2.gsub(","," ").split(" ")
            0.upto(xy.size/2 - 1) {|index| corners << Point.from_x_y(xy[index*2 + 1].to_f,xy[index*2].to_f)}
            @geometry = Envelope.from_points(corners)
          else
            raise GeorssFormatError.new("Bad Simple GeoRSS format: Unknown geometry type")
          end

          #geometry found: parse tags
          return unless with_tags

          @georss_tags.featuretypetag = $1 if tags =~ /featuretypetag=['"]([^"']*)['"]/
          @georss_tags.relationshiptag = $1 if tags =~ /relationshiptag=['"]([^'"]*)['"]/
          @georss_tags.elev = $1.to_f if tags =~ /elev=['"]([^'"]*)['"]/
          @georss_tags.floor = $1.to_i if tags =~ /floor=['"]([^'"]*)['"]/
          @georss_tags.radius = $1.to_f if tags =~ /radius=['"]([^'"]*)['"]/

        end
      end
    end
  end
end
