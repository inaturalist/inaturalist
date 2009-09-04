$:.unshift("lib/spatial_adapter/","lib/spatial_adapter/lib")

require 'rubygems'
require 'geo_ruby'
include GeoRuby::Shp4r

require 'active_record'
require 'yaml'

def shp_field_type_2_rails(type)
  case type
  when 'N' then :integer
  when 'F' then :float
  when 'D' then :date
  else
    :string
  end
end

def shp_geom_type_2_rails(type)
  case type
  when ShpType::POINT then :point
  when ShpType::POLYLINE then :multi_line_string
  when ShpType::POLYGON then :multi_polygon
  when ShpType::MULTIPOINT then :multi_point 
  end
end

#create an active record connection to a database
ActiveRecord::Base.establish_connection(YAML.load_file('db.yml'))

#add options depending on the type of database
if ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
  options = "TYPE=MyISAM" #for MySQL <= 5.0.16 : only MyISAM tables support geometric types
else
  options = ""
end

#load the correct spatial adapter depending on the type of the selected database : the required file is called init since it is originally a rails plugin and that's what the entry file for the plugin has to be called
require 'init'

#go through all the shp files passed as argument
ARGV.each do |shp|
  shp_basename = File.basename(shp)
  if shp_basename =~ /(.*)\.shp/
    table_name = $1.downcase
    
    #drop in case it already exists
    begin
      ActiveRecord::Schema.drop_table(table_name)
    rescue
    end 
   
    #empty block : the columns will be added afterwards
    ActiveRecord::Schema.create_table(table_name,:options => options){}
    
    ShpFile.open(shp) do |shp|
      shp.fields.each do |field|
        ActiveRecord::Schema.add_column(table_name, field.name.downcase, shp_field_type_2_rails(field.type))
      end
      
      #add the geometric column in the_geom
      ActiveRecord::Schema.add_column(table_name,"the_geom",shp_geom_type_2_rails(shp.shp_type),:null => false)
      #add an index
      ActiveRecord::Schema.add_index(table_name,"the_geom",:spatial => true)

      #add the data
      #create a subclass of ActiveRecord::Base wired to the table just created
      arTable = Class.new(ActiveRecord::Base) do
        set_table_name table_name
      end
      
      #go though all the shapes in the file
      shp.each do |shape|
        #create an ActiveRecord object
        record = arTable.new
        
        #fill the fields
        shp.fields.each do |field|
          record[field.name.downcase] = shape.data[field.name]
        end
        
        #fill the geometry
        record.the_geom = shape.geometry
        
        #save to the database
        record.save
      end
    end
  end
end

