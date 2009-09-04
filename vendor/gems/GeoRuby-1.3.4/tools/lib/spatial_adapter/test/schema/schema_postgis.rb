require File.dirname(__FILE__) + '/../common/common_postgis.rb'

#add some postgis specific tables
ActiveRecord::Schema.define() do

  create_table "table_points", :force => true do |t|
    t.string "data"
    t.point "geom", :null=>false
  end

  create_table "table_keyword_column_points", :force => true do |t|
    t.point "location", :null => false
  end

  create_table "table_line_strings", :force => true do |t|
    t.integer "value"
    t.line_string "geom", :null=>false
  end
  
  create_table "table_polygons", :force => true do |t|
    t.polygon "geom", :null=>false
  end

  create_table "table_multi_points", :force => true do |t|
    t.multi_point "geom", :null=>false
  end
  
  create_table "table_multi_line_strings", :force => true do |t|
    t.multi_line_string "geom", :null=>false
  end

  create_table "table_multi_polygons", :force => true do |t|
    t.multi_polygon "geom", :null=>false
  end

  create_table "table_geometries", :force => true do |t|
    t.geometry "geom", :null=>false
  end

  create_table "table_geometry_collections", :force => true do |t|
    t.geometry_collection "geom", :null=>false
  end

  create_table "table3dz_points", :force => true do |t|
    t.column "data", :string
    t.point "geom", :null => false , :with_z => true
  end

  create_table "table3dm_points", :force => true do |t|
    t.point "geom", :null => false , :with_m => true
  end

  create_table "table4d_points", :force => true do |t|
    t.point "geom", :null => false, :with_m => true, :with_z => true
  end

   create_table "table_srid_line_strings", :force => true do |t|
    t.line_string "geom", :null => false , :srid => 123
  end

  create_table "table_srid4d_polygons", :force => true do |t|
    t.polygon "geom", :with_m => true, :with_z => true, :srid => 123
  end
 
end
