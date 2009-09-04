require 'active_record'
require 'geo_ruby'
require 'common_spatial_adapter'

include GeoRuby::SimpleFeatures

#add a method to_yaml to the Geometry class which will transform a geometry in a form suitable to be used in a YAML file (such as in a fixture)
GeoRuby::SimpleFeatures::Geometry.class_eval do
  def to_fixture_format
    "!binary | #{[(255.chr * 4) + as_wkb].pack('m').gsub(/\s+/,"")}"
  end
end

ActiveRecord::Base.class_eval do
  require 'active_record/version'

  #For Rails < 1.2
  if ActiveRecord::VERSION::STRING < "1.15.1"
    def self.construct_conditions_from_arguments(attribute_names, arguments)
      conditions = []
      attribute_names.each_with_index do |name, idx| 
        if columns_hash[name].is_a?(SpatialColumn)
          #when the discriminating column is spatial, always use the MBRIntersects (bounding box intersection check) operator : the user can pass either a geometric object (which will be transformed to a string using the quote method of the database adapter) or an array with the corner points of a bounding box
          if arguments[idx].is_a?(Array)
            #using some georuby utility : The multipoint has a bbox whose corners are the 2 points passed as parameters : [ pt1, pt2]
            arguments[idx]= MultiPoint.from_coordinates(arguments[idx])
          elsif arguments[idx].is_a?(Envelope)
            arguments[idx]= MultiPoint.from_points([arguments[idx].lower_corner,arguments[idx].upper_corner])
          end
          conditions << "MBRIntersects(?, #{table_name}.#{connection.quote_column_name(name)}) " 
        else
          conditions << "#{table_name}.#{connection.quote_column_name(name)} #{attribute_condition(arguments[idx])} " 
        end
      end
      [ conditions.join(" AND "), *arguments[0...attribute_names.length] ]
    end

  else
    def self.get_conditions(attrs)
      attrs.map do |attr, value|
        if columns_hash[attr].is_a?(SpatialColumn)
          if value.is_a?(Array)
            #using some georuby utility : The multipoint has a bbox whose corners are the 2 points passed as parameters : [ pt1, pt2]
            attrs[attr]= MultiPoint.from_coordinates(value)
          elsif value.is_a?(Envelope)
            attrs[attr]= MultiPoint.from_points([value.lower_corner,value.upper_corner])
          end
          "MBRIntersects(?, #{table_name}.#{connection.quote_column_name(attr)}) " 
        else
          #original stuff
          "#{table_name}.#{connection.quote_column_name(attr)} #{attribute_condition(value)}"
        end
      end.join(' AND ')
    end
    def self.get_rails2_conditions(attrs)
      attrs.map do |attr, value|
        attr = attr.to_s
        if columns_hash[attr].is_a?(SpatialColumn)
         if value.is_a?(Array)
            #using some georuby utility : The multipoint has a bbox whose corners are the 2 points passed as parameters : [ pt1, pt2]
            attrs[attr.to_sym]=MultiPoint.from_coordinates(value)
          elsif value.is_a?(Envelope)
            attrs[attr.to_sym]=MultiPoint.from_points([value.lower_corner,value.upper_corner])
          end
          "MBRIntersects(?, #{table_name}.#{connection.quote_column_name(attr)}) " 
        else
          #original stuff
          # Extract table name from qualified attribute names.
          if attr.include?('.')
            table_name, attr = attr.split('.', 2)
            table_name = connection.quote_table_name(table_name)
          else
            table_name = quoted_table_name
          end
          "#{table_name}.#{connection.quote_column_name(attr)} #{attribute_condition(value)}"
        end
      end.join(' AND ')
    end
    if ActiveRecord::VERSION::STRING == "1.15.1"
      def self.sanitize_sql_hash(attrs)
        conditions = get_conditions(attrs)
        replace_bind_variables(conditions, attrs.values)
      end
    elsif ActiveRecord::VERSION::STRING.starts_with?("1.15")
      #For Rails >= 1.2
      def self.sanitize_sql_hash(attrs)
        conditions = get_conditions(attrs)
        replace_bind_variables(conditions, expand_range_bind_variables(attrs.values))
      end
    else
      #For Rails >= 2
      def self.sanitize_sql_hash_for_conditions(attrs)
        conditions = get_rails2_conditions(attrs)
        replace_bind_variables(conditions, expand_range_bind_variables(attrs.values))
      end
    end
  end
end


ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
  
  include SpatialAdapter

  alias :original_native_database_types :native_database_types
  def native_database_types
    original_native_database_types.merge!(geometry_data_types)
  end
 
  alias :original_quote :quote
  #Redefines the quote method to add behaviour for when a Geometry is encountered ; used when binding variables in find_by methods
  def quote(value, column = nil)
    if value.kind_of?(GeoRuby::SimpleFeatures::Geometry)
      "GeomFromWKB(0x#{value.as_hex_wkb},#{value.srid})"
    else
      original_quote(value,column)
    end
  end
  
  #Redefinition of columns to add the information that a column is geometric
  def columns(table_name, name = nil)#:nodoc:
    sql = "SHOW FIELDS FROM #{table_name}"
    columns = []
    execute(sql, name).each do |field| 
      if field[1] =~ /geometry|point|linestring|polygon|multipoint|multilinestring|multipolygon|geometrycollection/i
        #to note that the column is spatial
        columns << ActiveRecord::ConnectionAdapters::SpatialMysqlColumn.new(field[0], field[4], field[1], field[2] == "YES")
      else
        columns << ActiveRecord::ConnectionAdapters::MysqlColumn.new(field[0], field[4], field[1], field[2] == "YES")
      end
    end
    columns
  end


  #operations relative to migrations

  #Redefines add_index to support the case where the index is spatial
  #If the :spatial key in the options table is true, then the sql string for a spatial index is created
  def add_index(table_name,column_name,options = {})
    index_name = options[:name] || index_name(table_name,:column => Array(column_name))
    
    if options[:spatial]
      execute "CREATE SPATIAL INDEX #{index_name} ON #{table_name} (#{Array(column_name).join(", ")})"
    else
      index_type = options[:unique] ? "UNIQUE" : ""
      #all together
      execute "CREATE #{index_type} INDEX #{index_name} ON #{table_name} (#{Array(column_name).join(", ")})"
    end
  end

  #Check the nature of the index : If it is SPATIAL, it is indicated in the IndexDefinition object (redefined to add the spatial flag in spatial_adapter_common.rb)
  def indexes(table_name, name = nil)#:nodoc:
    indexes = []
    current_index = nil
    execute("SHOW KEYS FROM #{table_name}", name).each do |row|
      if current_index != row[2]
        next if row[2] == "PRIMARY" # skip the primary key
        current_index = row[2]
        indexes << ActiveRecord::ConnectionAdapters::IndexDefinition.new(row[0], row[2], row[1] == "0", row[10] == "SPATIAL",[])
      end
      indexes.last.columns << row[4]
    end
    indexes
  end
        
  #Get the table creation options : Only the engine for now. The text encoding could also be parsed and returned here.
  def options_for(table)
    result = execute("show table status like '#{table}'")
    engine = result.fetch_row[1]
    if engine !~ /inno/i #inno is default so do nothing for it in order not to clutter the migration
      "ENGINE=#{engine}" 
    else
      nil
    end
  end
end


module ActiveRecord
  module ConnectionAdapters
    class SpatialMysqlColumn < MysqlColumn

      include SpatialColumn
      
      #MySql-specific geometry string parsing. By default, MySql returns geometries in strict wkb format with "0" characters in the first 4 positions.
      def self.string_to_geometry(string)
        return string unless string.is_a?(String)
        begin
          GeoRuby::SimpleFeatures::Geometry.from_ewkb(string[4..-1])
        rescue Exception => exception
          nil
        end
      end
    end
  end
end
