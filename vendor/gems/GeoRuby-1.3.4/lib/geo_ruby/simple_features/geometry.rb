module GeoRuby#:nodoc:
  module SimpleFeatures
    #arbitrary default SRID
    DEFAULT_SRID=-1
        
    #Root of all geometric data classes.
    #Objects of class Geometry should not be instantiated.
    class Geometry
      #SRID of the geometry
      attr_reader :srid #writer defined below
      #Flag indicating if the z ordinate of the geometry is meaningful
      attr_accessor :with_z
      #Flag indicating if the m ordinate of the geometry is meaningful
      attr_accessor :with_m
      
      def initialize(srid=DEFAULT_SRID,with_z=false,with_m=false)
        @srid=srid
        @with_z=with_z
        @with_m=with_m
      end

      def srid=(new_srid)
        @srid = new_srid
        unless self.is_a?(Point)
          self.each do |geom|
            geom.srid=new_srid
          end
        end
      end

      
      #to be implemented in subclasses
      def bounding_box
      end

      #to be implemented in subclasses
      def m_range
      end
      
      #Returns an Envelope object for the geometry
      def envelope
        Envelope.from_points(bounding_box,srid,with_z)
      end
            
      #Outputs the geometry as an EWKB string.
      #The +allow_srid+, +allow_z+ and +allow_m+ arguments allow the output to include srid, z and m respectively if they are present in the geometry. If these arguments are set to false, srid, z and m are not included, even if they are present in the geometry. By default, the output string contains all the information in the object.
      def as_ewkb(allow_srid=true,allow_z=true,allow_m=true)
        ewkb="";
       
        ewkb << 1.chr #little_endian by default
        
        type= binary_geometry_type
        if @with_z and allow_z
          type = type | Z_MASK
        end
        if @with_m and allow_m
          type = type | M_MASK
        end
        if allow_srid
          type = type | SRID_MASK
          ewkb << [type,@srid].pack("VV")
        else
          ewkb << [type].pack("V")
        end
        
        ewkb << binary_representation(allow_z,allow_m)
      end
      
      #Outputs the geometry as a strict WKB string.
      def as_wkb
        as_ewkb(false,false,false)
      end

      #Outputs the geometry as a HexEWKB string. It is almost the same as a WKB string, except that each byte of a WKB string is replaced by its hexadecimal 2-character representation in a HexEWKB string.
      def as_hex_ewkb(allow_srid=true,allow_z=true,allow_m=true)
      	as_ewkb(allow_srid, allow_z, allow_m).unpack('H*').join('').upcase
      end
      #Outputs the geometry as a strict HexWKB string
      def as_hex_wkb
        as_hex_ewkb(false,false,false)
      end

      #Outputs the geometry as an EWKT string.
      def as_ewkt(allow_srid=true,allow_z=true,allow_m=true)
        if allow_srid
          ewkt="SRID=#{@srid};"
        else
          ewkt=""
        end
        ewkt << text_geometry_type 
        ewkt << "M" if @with_m and allow_m and (!@with_z or !allow_z) #to distinguish the M from the Z when there is actually no Z... 
        ewkt << "(" << text_representation(allow_z,allow_m) << ")"        
      end
      
      #Outputs the geometry as strict WKT string.
      def as_wkt
        as_ewkt(false,false,false)
      end

      #Outputs the geometry in georss format. 
      #Assumes the geometries are in latlon format, with x as lon and y as lat.
      #Pass the <tt>:dialect</tt> option to swhit format. Possible values are: <tt>:simple</tt> (default), <tt>:w3cgeo</tt> and <tt>:gml</tt>.
      def as_georss(options = {})
        dialect= options[:dialect] || :simple
        case(dialect)
        when :simple
          geom_attr = ""
          geom_attr += " featuretypetag=\"#{options[:featuretypetag]}\"" if options[:featuretypetag]
          geom_attr += " relationshiptag=\"#{options[:relationshiptag]}\"" if options[:relationshiptag]
          geom_attr += " floor=\"#{options[:floor]}\"" if options[:floor]
          geom_attr += " radius=\"#{options[:radius]}\"" if options[:radius]
          geom_attr += " elev=\"#{options[:elev]}\"" if options[:elev]
          georss_simple_representation(options.merge(:geom_attr => geom_attr))
        when :w3cgeo
          georss_w3cgeo_representation(options)
        when :gml
          georss_gml_representation(options)
        end
      end

      #Iutputs the geometry in kml format : options are <tt>:id</tt>, <tt>:tesselate</tt>, <tt>:extrude</tt>,
      #<tt>:altitude_mode</tt>. If the altitude_mode option is not present, the Z (if present) will not be output (since
      #it won't be used by GE anyway: clampToGround is the default)
      def as_kml(options = {})
        id_attr = ""
        id_attr = " id=\"#{options[:id]}\"" if options[:id]

        geom_data = ""
        geom_data += "<extrude>#{options[:extrude]}</extrude>\n" if options[:extrude]
        geom_data += "<tesselate>#{options[:tesselate]}</tesselate>\n" if options[:tesselate]
        geom_data += "<altitudeMode>#{options[:altitude_mode]}</altitudeMode>\n" if options[:altitude_mode]
        
        allow_z = (with_z || !options[:altitude].nil? )&& (!options[:altitude_mode].nil?) && options[:atitude_mode] != "clampToGround"
        fixed_z = options[:altitude]
        
        kml_representation(options.merge(:id_attr => id_attr, :geom_data => geom_data, :allow_z => allow_z, :fixed_z => fixed_z))
      end
      
      #Creates a geometry based on a EWKB string. The actual class returned depends of the content of the string passed as argument. Since WKB strings are a subset of EWKB, they are also valid.
      def self.from_ewkb(ewkb)
        factory = GeometryFactory::new
        ewkb_parser= EWKBParser::new(factory)
        ewkb_parser.parse(ewkb)
        factory.geometry
      end
      #Creates a geometry based on a HexEWKB string
      def self.from_hex_ewkb(hexewkb)
        factory = GeometryFactory::new
        hexewkb_parser= HexEWKBParser::new(factory)
        hexewkb_parser.parse(hexewkb)
        factory.geometry
      end
      #Creates a geometry based on a EWKT string. Since WKT strings are a subset of EWKT, they are also valid.
      def self.from_ewkt(ewkt)
        factory = GeometryFactory::new
        ewkt_parser= EWKTParser::new(factory)
        ewkt_parser.parse(ewkt)
        factory.geometry
      end
      
      #sends back a geometry based on the GeoRSS string passed as argument
      def self.from_georss(georss)
        georss_parser= GeorssParser::new
        georss_parser.parse(georss)
        georss_parser.geometry
      end      
      #sends back an array: The first element is the goemetry based on the GeoRSS string passed as argument. The second one is the GeoRSSTags (found only with the Simple format)
      def self.from_georss_with_tags(georss)
        georss_parser= GeorssParser::new
        georss_parser.parse(georss,true)
        [georss_parser.geometry, georss_parser.georss_tags]
      end
      
      #Sends back a geometry from a KML encoded geometry string.
      #Limitations : Only supports points, linestrings and polygons (no collection for now).
      #Addapted from Pramukta's code
      def self.from_kml(kml)
        return GeoRuby::SimpleFeatures::Geometry.from_ewkt(kml_to_wkt(kml))
      end

      require 'rexml/document'
      def self.kml_to_wkt(kml)
        doc = REXML::Document.new(kml)
        wkt = ""
        if ["Point", "LineString", "Polygon" ].include?(doc.root.name)
          case doc.root.name 
          when "Point" then
            coords = doc.elements["/Point/coordinates"].text.gsub(/\n/," ")
            wkt = doc.root.name.upcase + "(" + split_coords(coords).join(' ') + ")"
          when "LineString" then
            coords = doc.elements["/LineString/coordinates"].text.gsub(/\n/," ")
            coords = split_coords(coords)
            wkt = doc.root.name.upcase + "(" + coords.join(",") + ")"
          when "Polygon" then
            # polygons have one outer ring and zero or more inner rings
            bounds = []
            bounds << doc.elements["/Polygon/outerBoundaryIs/LinearRing/coordinates"].text
            inner_coords_elements = doc.elements.each("/Polygon/innerBoundaryIs/LinearRing/coordinates") do |inner_coords|
              inner_coords = inner_coords.text
              bounds << inner_coords
            end
            
            wkt = doc.root.name.upcase + "(" + bounds.map do |bound|
              bound.gsub!(/\n/, " ")
              bound = split_coords(bound)
              if bound.first != bound.last
                bound.push bound.first
              end
              "(" + bound.join(",") + ")"
            end.join(",") + ")"
          end
        end
        return wkt 
      end

      private

      def self.split_coords(coords)
        coords.split(" ").collect { |coord|
          coord.gsub(","," ")
        }
      end
    end
  end
end
