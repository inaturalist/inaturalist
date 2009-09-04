require 'date'
require 'fileutils' if !defined?(FileUtils)
require  File.dirname(__FILE__) + '/dbf'


module GeoRuby
  module Shp4r
    
    #Enumerates all the types of SHP geometries. The MULTIPATCH one is the only one not currently supported by GeoRuby.
    module ShpType
      NULL_SHAPE = 0
      POINT = 1 
      POLYLINE = 3 
      POLYGON = 5 
      MULTIPOINT = 8
      POINTZ = 11 
      POLYLINEZ = 13
      POLYGONZ = 15 
      MULTIPOINTZ = 18
      POINTM = 21 
      POLYLINEM = 23
      POLYGONM = 25 
      MULTIPOINTM = 28 
    end

    #An interface to an ESRI shapefile (actually 3 files : shp, shx and dbf). Currently supports only the reading of geometries.
    class ShpFile
      attr_reader :shp_type, :record_count, :xmin, :ymin, :xmax, :ymax, :zmin, :zmax, :mmin, :mmax, :file_root, :file_length

      include Enumerable

      #Opens a SHP file. Both "abc.shp" and "abc" are accepted. The files "abc.shp", "abc.shx" and "abc.dbf" must be present
      def initialize(file)
        #strip the shp out of the file if present
        @file_root = file.gsub(/.shp$/i,"")
        #check existence of shp, dbf and shx files       
        unless File.exists?(@file_root + ".shp") and File.exists?(@file_root + ".dbf") and File.exists?(@file_root + ".shx")
          raise MalformedShpException.new("Missing one of shp, dbf or shx for: #{@file}")
        end

        @dbf = Dbf::Reader.open(@file_root + ".dbf")
        @shx = File.open(@file_root + ".shx","rb")
        @shp = File.open(@file_root + ".shp","rb")
        read_index
      end

      #force the reopening of the files compsing the shp. Close before calling this.
      def reload!
        initialize(@file_root)
      end
      
      #opens a SHP "file". If a block is given, the ShpFile object is yielded to it and is closed upon return. Else a call to <tt>open</tt> is equivalent to <tt>ShpFile.new(...)</tt>.
      def self.open(file)
        shpfile = ShpFile.new(file)
        if block_given?
          yield shpfile
          shpfile.close
        else
          shpfile
        end
      end

      #create a new Shapefile of the specified shp type (see ShpType) and with the attribute specified in the +fields+ array (see Dbf::Field). If a block is given, the ShpFile object newly created is passed to it.
      def self.create(file,shp_type,fields,&proc)
        file_root = file.gsub(/.shp$/i,"")
        shx_io = File.open(file_root + ".shx","wb")
        shp_io = File.open(file_root + ".shp","wb")
        dbf_io = File.open(file_root + ".dbf","wb")
        str = [9994,0,0,0,0,0,50,1000,shp_type,0,0,0,0,0,0,0,0].pack("N7V2E8")
        shp_io << str
        shx_io << str
        rec_length = 1 + fields.inject(0) {|s,f| s + f.length} #+1 for the prefixed space (active record marker)
        dbf_io << [3,107,7,7,0,33 + 32 * fields.length,rec_length ].pack("c4Vv2x20") #32 bytes for first part of header
        fields.each do |field|
          dbf_io << [field.name,field.type,field.length,field.decimal].pack("a10xax4CCx14")
        end
        dbf_io << ['0d'].pack("H2")
        
        shx_io.close
        shp_io.close
        dbf_io.close

        open(file,&proc)

      end
      
      #Closes a shapefile
      def close
        @dbf.close
        @shx.close
        @shp.close
      end

      #starts a transaction, to buffer physical file operations on the shapefile components.
      def transaction
        trs = ShpTransaction.new(self,@dbf)
        if block_given?
          answer = yield trs
          if answer == :rollback
            trs.rollback
          elsif !trs.rollbacked
            trs.commit
          end
        else
          trs
        end
      end
      
      #return the description of data fields
      def fields
        @dbf.fields
      end
      
      #Tests if the file has no record
      def empty?
        record_count == 0
      end
      
      #Goes through each record
      def each
        (0...record_count).each do |i|
          yield get_record(i)
        end
      end
      alias :each_record :each
      
      #Returns record +i+
      def [](i)
        get_record(i)
      end

      #Returns all the records
      def records
        Array.new(record_count) do |i|
          get_record(i)
        end
      end

      private   
      def read_index
        @file_length, @shp_type, @xmin, @ymin, @xmax, @ymax, @zmin, @zmax, @mmin,@mmax = @shx.read(100).unpack("x24Nx4VE8")
        @record_count = (@file_length - 50) / 4
        if @record_count == 0 
          #initialize the bboxes to default values so if data added, they will be replaced
          @xmin, @ymin, @xmax, @ymax, @zmin, @zmax, @mmin,@mmax =  Float::MAX, Float::MAX, -Float::MAX, -Float::MAX, Float::MAX, -Float::MAX, Float::MAX, -Float::MAX
        end
        unless @record_count == @dbf.record_count
          raise MalformedShpException.new("Not the same number of records in SHP and DBF")
        end
      end

      #TODO : refactor to minimize redundant code
      def get_record(i)
        return nil if record_count <= i or i < 0
        dbf_record = @dbf.record(i)
        @shx.seek(100 + 8 * i) #100 is the header length
        offset,length = @shx.read(8).unpack("N2")
        @shp.seek(offset * 2 + 8)
        rec_shp_type = @shp.read(4).unpack("V")[0]

        case(rec_shp_type)
        when ShpType::POINT
          x, y = @shp.read(16).unpack("E2")
          geometry = GeoRuby::SimpleFeatures::Point.from_x_y(x,y)
        when ShpType::POLYLINE #actually creates a multi_polyline
          @shp.seek(32,IO::SEEK_CUR) #extent 
          num_parts, num_points = @shp.read(8).unpack("V2")
          parts =  @shp.read(num_parts * 4).unpack("V" + num_parts.to_s)
          parts << num_points #indexes for LS of idx i go to parts of idx i to idx i +1
          points = Array.new(num_points) do
            x, y = @shp.read(16).unpack("E2")
            GeoRuby::SimpleFeatures::Point.from_x_y(x,y)
          end
          line_strings = Array.new(num_parts) do |i|
            GeoRuby::SimpleFeatures::LineString.from_points(points[(parts[i])...(parts[i+1])])
          end
          geometry = GeoRuby::SimpleFeatures::MultiLineString.from_line_strings(line_strings)
        when ShpType::POLYGON
          #TODO : TO CORRECT
          #does not take into account the possibility that the outer loop could be after the inner loops in the SHP + more than one outer loop
          #Still sends back a multi polygon (so the correction above won't change what gets sent back)
          @shp.seek(32,IO::SEEK_CUR)
          num_parts, num_points = @shp.read(8).unpack("V2")
          parts =  @shp.read(num_parts * 4).unpack("V" + num_parts.to_s)
          parts << num_points #indexes for LS of idx i go to parts of idx i to idx i +1
          points = Array.new(num_points) do 
            x, y = @shp.read(16).unpack("E2")
            GeoRuby::SimpleFeatures::Point.from_x_y(x,y)
          end
          linear_rings = Array.new(num_parts) do |i|
            GeoRuby::SimpleFeatures::LinearRing.from_points(points[(parts[i])...(parts[i+1])])
          end
          geometry = GeoRuby::SimpleFeatures::MultiPolygon.from_polygons([GeoRuby::SimpleFeatures::Polygon.from_linear_rings(linear_rings)])
        when ShpType::MULTIPOINT
          @shp.seek(32,IO::SEEK_CUR)
          num_points = @shp.read(4).unpack("V")[0]
          points = Array.new(num_points) do
            x, y = @shp.read(16).unpack("E2")
            GeoRuby::SimpleFeatures::Point.from_x_y(x,y)
          end
          geometry = GeoRuby::SimpleFeatures::MultiPoint.from_points(points)


        when ShpType::POINTZ
          x, y, z, m = @shp.read(24).unpack("E4")
          geometry = GeoRuby::SimpleFeatures::Point.from_x_y_z_m(x,y,z,m)


        when ShpType::POLYLINEZ
          @shp.seek(32,IO::SEEK_CUR)
          num_parts, num_points = @shp.read(8).unpack("V2")
          parts =  @shp.read(num_parts * 4).unpack("V" + num_parts.to_s)
          parts << num_points #indexes for LS of idx i go to parts of idx i to idx i +1
          xys = Array.new(num_points) { @shp.read(16).unpack("E2") }
          @shp.seek(16,IO::SEEK_CUR)
          zs = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          @shp.seek(16,IO::SEEK_CUR)
          ms = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          points = Array.new(num_points) do |i|
            GeoRuby::SimpleFeatures::Point.from_x_y_z_m(xys[i][0],xys[i][1],zs[i],ms[i])
          end
          line_strings = Array.new(num_parts) do |i|
            GeoRuby::SimpleFeatures::LineString.from_points(points[(parts[i])...(parts[i+1])],GeoRuby::SimpleFeatures::DEFAULT_SRID,true,true)
          end
          geometry = GeoRuby::SimpleFeatures::MultiLineString.from_line_strings(line_strings,GeoRuby::SimpleFeatures::DEFAULT_SRID,true,true)

          
        when ShpType::POLYGONZ
          #TODO : CORRECT

          @shp.seek(32,IO::SEEK_CUR)#extent 
          num_parts, num_points = @shp.read(8).unpack("V2")
          parts =  @shp.read(num_parts * 4).unpack("V" + num_parts.to_s)
          parts << num_points #indexes for LS of idx i go to parts of idx i to idx i +1
          xys = Array.new(num_points) { @shp.read(16).unpack("E2") }
          @shp.seek(16,IO::SEEK_CUR)#extent 
          zs = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          @shp.seek(16,IO::SEEK_CUR)#extent 
          ms = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          points = Array.new(num_points) do |i|
            Point.from_x_y_z_m(xys[i][0],xys[i][1],zs[i],ms[i])
          end
          linear_rings = Array.new(num_parts) do |i|
            GeoRuby::SimpleFeatures::LinearRing.from_points(points[(parts[i])...(parts[i+1])],GeoRuby::SimpleFeatures::DEFAULT_SRID,true,true)
          end
          geometry = GeoRuby::SimpleFeatures::MultiPolygon.from_polygons([GeoRuby::SimpleFeatures::Polygon.from_linear_rings(linear_rings)],GeoRuby::SimpleFeatures::DEFAULT_SRID,true,true)


        when ShpType::MULTIPOINTZ
          @shp.seek(32,IO::SEEK_CUR)
          num_points = @shp.read(4).unpack("V")[0]
          xys = Array.new(num_points) { @shp.read(16).unpack("E2") }
          @shp.seek(16,IO::SEEK_CUR)
          zs = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          @shp.seek(16,IO::SEEK_CUR)
          ms = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          
          points = Array.new(num_points) do |i|
            Point.from_x_y_z_m(xys[i][0],xys[i][1],zs[i],ms[i])
          end
          
          geometry = GeoRuby::SimpleFeatures::MultiPoint.from_points(points,GeoRuby::SimpleFeatures::DEFAULT_SRID,true,true)

        when ShpType::POINTM
          x, y, m = @shp.read(24).unpack("E3")
          geometry = GeoRuby::SimpleFeatures::Point.from_x_y_m(x,y,m)

        when ShpType::POLYLINEM
          @shp.seek(32,IO::SEEK_CUR)
          num_parts, num_points = @shp.read(8).unpack("V2")
          parts =  @shp.read(num_parts * 4).unpack("V" + num_parts.to_s)
          parts << num_points #indexes for LS of idx i go to parts of idx i to idx i +1
          xys = Array.new(num_points) { @shp.read(16).unpack("E2") }
          @shp.seek(16,IO::SEEK_CUR)
          ms = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          points = Array.new(num_points) do |i|
            Point.from_x_y_m(xys[i][0],xys[i][1],ms[i])
          end
          line_strings = Array.new(num_parts) do |i|
            GeoRuby::SimpleFeatures::LineString.from_points(points[(parts[i])...(parts[i+1])],GeoRuby::SimpleFeatures::DEFAULT_SRID,false,true)
          end
          geometry = GeoRuby::SimpleFeatures::MultiLineString.from_line_strings(line_strings,GeoRuby::SimpleFeatures::DEFAULT_SRID,false,true)

          
        when ShpType::POLYGONM
          #TODO : CORRECT

          @shp.seek(32,IO::SEEK_CUR)
          num_parts, num_points = @shp.read(8).unpack("V2")
          parts =  @shp.read(num_parts * 4).unpack("V" + num_parts.to_s)
          parts << num_points #indexes for LS of idx i go to parts of idx i to idx i +1
          xys = Array.new(num_points) { @shp.read(16).unpack("E2") }
          @shp.seek(16,IO::SEEK_CUR)
          ms = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          points = Array.new(num_points) do |i|
            Point.from_x_y_m(xys[i][0],xys[i][1],ms[i])
          end
          linear_rings = Array.new(num_parts) do |i|
            GeoRuby::SimpleFeatures::LinearRing.from_points(points[(parts[i])...(parts[i+1])],GeoRuby::SimpleFeatures::DEFAULT_SRID,false,true)
          end
          geometry = GeoRuby::SimpleFeatures::MultiPolygon.from_polygons([GeoRuby::SimpleFeatures::Polygon.from_linear_rings(linear_rings)],GeoRuby::SimpleFeatures::DEFAULT_SRID,false,true)


        when ShpType::MULTIPOINTM
          @shp.seek(32,IO::SEEK_CUR)
          num_points = @shp.read(4).unpack("V")[0]
          xys = Array.new(num_points) { @shp.read(16).unpack("E2") }
          @shp.seek(16,IO::SEEK_CUR)
          ms = Array.new(num_points) {@shp.read(8).unpack("E")[0]}
          
          points = Array.new(num_points) do |i|
            Point.from_x_y_m(xys[i][0],xys[i][1],ms[i])
          end
          
          geometry = GeoRuby::SimpleFeatures::MultiPoint.from_points(points,GeoRuby::SimpleFeatures::DEFAULT_SRID,false,true)
        else
          geometry = nil
        end
        
        ShpRecord.new(geometry,dbf_record)
      end
    end
    
    #A SHP record : contains both the geometry and the data fields (from the DBF)
    class ShpRecord
      attr_reader :geometry , :data
      
      def initialize(geometry, data)
        @geometry = geometry
        @data = data
      end

      #Tests if the geometry is a NULL SHAPE
      def has_null_shape?
        @geometry.nil?
      end
    end

    #An object returned from ShpFile#transaction. Buffers updates to a Shapefile
    class ShpTransaction   
      attr_reader :rollbacked
      
      def initialize(shp, dbf)
        @deleted = Hash.new
        @added = Array.new
        @shp = shp
        @dbf = dbf
      end

      #delete a record. Does not take into account the records added in the current transaction
      def delete(i)
        raise UnexistantRecordException.new("Invalid index : #{i}") if @shp.record_count <= i 
        @deleted[i] = true
      end

      #Update a record. In effect just a delete followed by an add.
      def update(i, record)
        delete(i)
        add(record)
      end
      
      #add a ShpRecord at the end
      def add(record)
        record_type = to_shp_type(record.geometry)
        raise IncompatibleGeometryException.new("Incompatible type") unless record_type==@shp.shp_type
        @added << record
      end

      #updates the physical files
      def commit
        @shp.close
        @shp_r = open(@shp.file_root + ".shp", "rb")
        @dbf_r = open(@shp.file_root + ".dbf", "rb")
        @shp_io = open(@shp.file_root + ".shp.tmp.shp", "wb")
        @shx_io = open(@shp.file_root + ".shx.tmp.shx", "wb")
        @dbf_io = open(@shp.file_root + ".dbf.tmp.dbf", "wb")
        index = commit_delete
        min_x,max_x,min_y,max_y,min_z,max_z,min_m,max_m = commit_add(index)
        commit_finalize(min_x,max_x,min_y,max_y,min_z,max_z,min_m,max_m)
        @shp_r.close
        @dbf_r.close
        @dbf_io.close
        @shp_io.close
        @shx_io.close
        FileUtils.move(@shp.file_root + ".shp.tmp.shp", @shp.file_root + ".shp")
        FileUtils.move(@shp.file_root + ".shx.tmp.shx", @shp.file_root + ".shx")
        FileUtils.move(@shp.file_root + ".dbf.tmp.dbf", @shp.file_root + ".dbf")
        
        @deleted = Hash.new
        @added = Array.new
        
        @shp.reload!
       end

      #prevents the udpate from taking place
      def rollback
        @deleted = Hash.new
        @added = Array.new
        @rollbacked = true
      end

      private 
      
      def to_shp_type(geom)
        root = if geom.is_a? GeoRuby::SimpleFeatures::Point
                 "POINT"
               elsif geom.is_a? GeoRuby::SimpleFeatures::LineString
                 "POLYLINE"
               elsif geom.is_a?  GeoRuby::SimpleFeatures::Polygon
                 "POLYGON"
               elsif geom.is_a?  GeoRuby::SimpleFeatures::MultiPoint
                 "MULTIPOINT"
               elsif geom.is_a?  GeoRuby::SimpleFeatures::MultiLineString
                 "POLYLINE"
               elsif geom.is_a?  GeoRuby::SimpleFeatures::MultiPolygon
                 "POLYGON"
               else
                 false
               end
        return false if !root

        if geom.with_z
          root = root + "Z"
        elsif geom.with_m
          root = root + "M"
        end
        eval "ShpType::" + root
      end

      def commit_add(index)
        max_x, min_x, max_y, min_y,max_z,min_z,max_m,min_m = @shp.xmax,@shp.xmin,@shp.ymax,@shp.ymin,@shp.zmax,@shp.zmin,@shp.mmax,@shp.mmin
        @added.each do |record|
          @dbf_io << ['20'].pack('H2')
          @dbf.fields.each do |field|
            data = record.data[field.name]
            str = if field.type == 'D'
                    sprintf("%04i%02i%02i",data.year,data.month,data.mday)
                  elsif field.type == 'L'
                    if data
                      "T" 
                    else
                      "F"
                    end
                  else 
                    data.to_s
                  end
            @dbf_io << [str].pack("A#{field.length}")
          end
          
          shp_str,min_xp,max_xp,min_yp,max_yp,min_zp,max_zp,min_mp,max_mp = build_shp_geometry(record.geometry)
          max_x = max_xp if max_xp > max_x
          min_x = min_xp if min_xp < min_x
          max_y = max_yp if max_yp > max_y
          min_y = min_yp if min_yp < min_y
          max_z = max_zp if max_zp > max_z
          min_z = min_zp if min_zp < min_z
          max_m = max_mp if max_mp > max_m
          min_m = min_mp if min_mp < min_m
          length = (shp_str.length/2 + 2).to_i #num of 16-bit words; geom type is included (+2)
          @shx_io << [(@shp_io.pos/2).to_i,length].pack("N2")
          @shp_io << [index,length,@shp.shp_type].pack("N2V")
          @shp_io << shp_str
          index += 1
        end
        @shp_io.flush
        @shx_io.flush
        @dbf_io.flush
        [min_x,max_x,min_y,max_y,min_z,max_z,min_m,max_m]
      end
      
      def commit_delete
        @shp_r.rewind
        header = @shp_r.read(100)
        @shp_io << header
        @shx_io << header
        index = 1
        while(!@shp_r.eof?)
          icur,length = @shp_r.read(8).unpack("N2")
          unless(@deleted[icur-1])
            @shx_io << [(@shp_io.pos/2).to_i,length].pack("N2")
            @shp_io << [index,length].pack("N2")
            @shp_io << @shp_r.read(length * 2)
            index += 1
          else
            @shp_r.seek(length * 2,IO::SEEK_CUR)
          end
        end
        @shp_io.flush
        @shx_io.flush
        
        @dbf_r.rewind
        @dbf_io << @dbf_r.read(@dbf.header_length)
        icur = 0
        while(!@dbf_r.eof?)
          unless(@deleted[icur])
            @dbf_io << @dbf_r.read(@dbf.record_length)
          else
            @dbf_r.seek(@dbf.record_length,IO::SEEK_CUR)
          end
          icur += 1
        end
        @dbf_io.flush
        index
      end

      def commit_finalize(min_x,max_x,min_y,max_y,min_z,max_z,min_m,max_m)
        #update size in shp and dbf + extent and num records in dbf
        @shp_io.seek(0,IO::SEEK_END)
        shp_size = @shp_io.pos / 2
        @shx_io.seek(0,IO::SEEK_END)
        shx_size= @shx_io.pos / 2
        @shp_io.seek(24)
        @shp_io.write([shp_size].pack("N"))
        @shx_io.seek(24)
        @shx_io.write([shx_size].pack("N"))
        @shp_io.seek(36)
        @shx_io.seek(36)
        str = [min_x,min_y,max_x,max_y,min_z,max_z,min_m,max_m].pack("E8")
        @shp_io.write(str)
        @shx_io.write(str)

        @dbf_io.seek(4)
        @dbf_io.write([@dbf.record_count + @added.length - @deleted.length].pack("V"))
      end

      def build_shp_geometry(geometry)
        m_range = nil
        answer = 
        case @shp.shp_type
        when ShpType::POINT
          bbox = geometry.bounding_box
          [geometry.x,geometry.y].pack("E2")
        when ShpType::POLYLINE
          str,bbox = create_bbox(geometry)
          build_polyline(geometry,str)
        when ShpType::POLYGON
          str,bbox = create_bbox(geometry)
          build_polygon(geometry,str)
        when ShpType::MULTIPOINT
          str,bbox = create_bbox(geometry)
          build_multi_point(geometry,str)
        when ShpType::POINTZ
          bbox = geometry.bounding_box
          [geometry.x,geometry.y,geometry.z,geometry.m].pack("E4")
        when ShpType::POLYLINEZ
          str,bbox = create_bbox(geometry)
          m_range = geometry.m_range
          build_polyline(geometry,str)
          build_polyline_zm(geometry,:@z,[bbox[0].z,bbox[1].z],str)
          build_polyline_zm(geometry,:@m,m_range,str)
        when ShpType::POLYGONZ 
          str,bbox = create_bbox(geometry)
          m_range = geometry.m_range
          build_polygon(geometry,str)
          build_polygon_zm(geometry,:@z,[bbox[0].z,bbox[1].z],str)
          build_polygon_zm(geometry,:@m,m_range,str)
        when ShpType::MULTIPOINTZ
          str,bbox = create_bbox(geometry)
          m_range = geometry.m_range
          build_multi_point(geometry,str)
          build_multi_point_zm(geometry,:@z,[bbox[0].z,bbox[1].z],str)
          build_multi_point_zm(geometry,:@m,m_range,str)
        when ShpType::POINTM 
          bbox = geometry.bounding_box
          [geometry.x,geometry.y,geometry.m].pack("E3")
        when ShpType::POLYLINEM
          str,bbox = create_bbox(geometry)
          m_range = geometry.m_range
          build_polyline(geometry,str)
          build_polyline_zm(geometry,:@m,m_range,str)
        when ShpType::POLYGONM 
          str,bbox = create_bbox(geometry)
          m_range = geometry.m_range
          build_polygon(geometry,str)
          build_polygon_zm(geometry,:@m,m_range,str)
        when ShpType::MULTIPOINTM
          str,bbox = create_bbox(geometry)
          m_range = geometry.m_range
          build_multi_point(geometry,str)
          build_multi_point_zm(geometry,:@m,m_range,str)
        end
        m_range ||= [0,0]
        [answer,bbox[0].x,bbox[1].x,bbox[0].y,bbox[1].y,bbox[0].z || 0, bbox[1].z || 0, m_range[0], m_range[1]]
      end
      
      def create_bbox(geometry)
        bbox = geometry.bounding_box
        [[bbox[0].x,bbox[0].y,bbox[1].x,bbox[1].y].pack("E4"),bbox]
      end
      
      def build_polyline(geometry,str)
        if geometry.is_a? GeoRuby::SimpleFeatures::LineString
          str << [1,geometry.length,0].pack("V3")
          geometry.each do |point|
              str << [point.x,point.y].pack("E2")
          end
        else
          #multilinestring
          str << [geometry.length,geometry.inject(0) {|l, ls| l + ls.length}].pack("V2")
          str << geometry.inject([0]) {|a,ls| a << (a.last + ls.length)}.pack("V#{geometry.length}") #last element of the previous array is dropped
          geometry.each do |ls|
            ls.each do |point|
              str << [point.x,point.y].pack("E2")
            end
          end
        end
        str
      end
      
      def build_polyline_zm(geometry,zm,range,str)
        str << range.pack("E2")
        if geometry.is_a? GeoRuby::SimpleFeatures::LineString
          geometry.each do |point|
            str << [point.instance_variable_get(zm)].pack("E")
          end
        else
          #multilinestring
          geometry.each do |ls|
            ls.each do |point|
              str << [point.instance_variable_get(zm)].pack("E")
            end
          end
        end
        str
      end
      
      def build_polygon(geometry,str)
        if geometry.is_a? GeoRuby::SimpleFeatures::Polygon
          str << [geometry.length,geometry.inject(0) {|l, lr| l + lr.length}].pack("V2")
          str << geometry.inject([0]) {|a,lr| a << (a.last + lr.length)}.pack("V#{geometry.length}") #last element of the previous array is dropped
          geometry.each do |lr|
            lr.each do |point|
              str << [point.x,point.y].pack("E2")
            end
          end
        else
          #multipolygon
          num_rings = geometry.inject(0) {|l, poly| l + poly.length}
          str << [num_rings, geometry.inject(0) {|l, poly| l + poly.inject(0) {|l2,lr| l2 + lr.length} }].pack("V2")
          str << geometry.inject([0]) {|a,poly| poly.inject(a) {|a2, lr| a2 << (a2.last + lr.length)}}.pack("V#{num_rings}") #last element of the previous array is dropped
          geometry.each do |poly|
            poly.each do |lr|
              lr.each do |point|
                str << [point.x,point.y].pack("E2")
              end
            end
          end
        end
        str
      end
      
      def build_polygon_zm(geometry,zm,range,str)
        str << range.pack("E2")
        if geometry.is_a? GeoRuby::SimpleFeatures::Polygon
          geometry.each do |lr|
            lr.each do |point|
              str << [point.instance_variable_get(zm)].pack("E")
            end
          end
        else
          geometry.each do |poly|
            poly.each do |lr|
              lr.each do |point|
                str << [point.instance_variable_get(zm)].pack("E")
              end
            end
          end
        end
        str
      end

      def build_multi_point(geometry,str)
        str << [geometry.length].pack("V")
        geometry.each do |point|
          str << [point.x,point.y].pack("E2")
        end
        str
      end

      def build_multi_point_zm(geometry,zm,range,str)
        str << range.pack("E2")
        geometry.each do |point|
          str << [point.instance_variable_get(zm)].pack("E")
        end
        str
      end
    end

    class MalformedShpException < StandardError
    end

    class UnexistantRecordException < StandardError
    end

    class IncompatibleGeometryException < StandardError
    end

    class IncompatibleDataException < StandardError
    end
  end
end
