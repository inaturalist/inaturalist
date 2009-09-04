# Copyright 2006 Keith Morrison (http://infused.org)
# Modified version of his DBF library (http://rubyforge.org/projects/dbf/)

module GeoRuby
  module Shp4r 
    module Dbf
      
      DBF_HEADER_SIZE = 32
      DATE_REGEXP = /([\d]{4})([\d]{2})([\d]{2})/
      VERSION_DESCRIPTIONS = {
        "02" => "FoxBase",
        "03" => "dBase III without memo file",
        "04" => "dBase IV without memo file",
        "05" => "dBase V without memo file",
        "30" => "Visual FoxPro",
        "31" => "Visual FoxPro with AutoIncrement field",
        "7b" => "dBase IV with memo file",
        "83" => "dBase III with memo file",
        "8b" => "dBase IV with memo file",
        "8e" => "dBase IV with SQL table",
        "f5" => "FoxPro with memo file",
        "fb" => "FoxPro without memo file"
      }
      
      class DBFError < StandardError; end
      class UnpackError < DBFError; end
      
      class Reader
        attr_reader :field_count
        attr_reader :fields
        attr_reader :record_count
        attr_reader :version
        attr_reader :last_updated
        attr_reader :header_length
        attr_reader :record_length
        
        def initialize(file)
          @data_file = File.open(file, 'rb')
          reload!
        end

        def self.open(file)
          reader = Reader.new(file)
          if block_given?
            yield reader
            reader.close
          else
            reader
          end
        end

        def close
          @data_file.close
        end
        
        def reload!
          get_header_info
          get_field_descriptors
        end
        
        def field(field_name)
          @fields.detect {|f| f.name == field_name.to_s}
        end
         
        # An array of all the records contained in the database file
        def records
          seek_to_record(0)
          @records ||= Array.new(@record_count) do |i|
            if active_record?
              build_record
            else
              seek_to_record(i + 1)
              nil
            end
          end
        end
        alias_method :rows, :records
        
        # Jump to record
        def record(index)
          seek_to_record(index)
          active_record? ? build_record : nil
        end
        
        alias_method :row, :record
        
        def version_description
          VERSION_DESCRIPTIONS[version]
        end
        
        private
        
        def active_record?
          @data_file.read(1).unpack('H2').to_s == '20' rescue false
        end
                
        def build_record
          record = DbfRecord.new
          @fields.each do |field| 
            case field.type
            when 'N'
              record[field.name] = unpack_integer(field) rescue nil
            when 'F'
              record[field.name] = unpack_float(field) rescue nil
            when 'D'
              raw = unpack_string(field).to_s.strip
              unless raw.empty?
                begin
                  record[field.name] = Time.gm(*raw.match(DATE_REGEXP).to_a.slice(1,3).map {|n| n.to_i})
                rescue
                  record[field.name] = Date.new(*raw.match(DATE_REGEXP).to_a.slice(1,3).map {|n| n.to_i}) rescue nil
                end
              end
            when 'L'
              record[field.name] = unpack_string(field) =~ /^(y|t)$/i ? true : false rescue false
            when 'C'
              record[field.name] = unpack_string(field).strip
            else
              record[field.name] = unpack_string(field)
            end
          end
          record
        end
        
        def get_header_info
          @data_file.rewind
          @version, @record_count, @header_length, @record_length = @data_file.read(DBF_HEADER_SIZE).unpack('H2xxxVvv')
          @field_count = (@header_length - DBF_HEADER_SIZE + 1) / DBF_HEADER_SIZE
        end
        
        def get_field_descriptors
          @fields = Array.new(@field_count) {|i| Field.new(*@data_file.read(32).unpack('a10xax4CC'))}
        end
         
        def seek(offset)
          @data_file.seek(@header_length + offset)
        end
        
        def seek_to_record(index)
          seek(@record_length * index)
        end
        
        def unpack_field(field)
          @data_file.read(field.length).unpack("a#{field.length}")
        end
        
        def unpack_string(field)
          unpack_field(field).to_s
        end
        
        def unpack_integer(field)
          unpack_string(field).to_i
        end
        
        def unpack_float(field)
          unpack_string(field).to_f
        end
        
      end
      
      class FieldError < StandardError; end
      
      class Field
        attr_reader :name, :type, :length, :decimal

        def initialize(name, type, length, decimal = 0)
          raise FieldError, "field length must be greater than 0" unless length > 0
          if type == 'N' and decimal != 0
            type = 'F'
          end
          @name, @type, @length, @decimal = name.strip, type,length, decimal
        end
      end
      
      class DbfRecord < Hash
      end
      
    end
  end
end
