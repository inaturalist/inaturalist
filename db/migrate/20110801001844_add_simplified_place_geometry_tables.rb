class AddSimplifiedPlaceGeometryTables < ActiveRecord::Migration
  def self.up
    create_table :states_simplified_1 do |t|
      t.integer :place_geometry_id
      t.integer :place_id
      t.multi_polygon :geom, :null => false
    end
    add_index :states_simplified_1, :place_id
    add_index :states_simplified_1, :place_geometry_id
    add_index :states_simplified_1, :geom, :spatial => true
    
    create_table :countries_simplified_1 do |t|
      t.integer :place_geometry_id
      t.integer :place_id
      t.multi_polygon :geom, :null => false
    end
    add_index :countries_simplified_1, :place_id
    add_index :countries_simplified_1, :place_geometry_id
    add_index :countries_simplified_1, :geom, :spatial => true
    
    create_table :counties_simplified_01 do |t|
      t.integer :place_geometry_id
      t.integer :place_id
      t.multi_polygon :geom, :null => false
    end
    add_index :counties_simplified_01, :place_id
    add_index :counties_simplified_01, :place_geometry_id
    add_index :counties_simplified_01, :geom, :spatial => true
  end

  def self.down
    drop_table :countries_simplified_1
    drop_table :states_simplified_1
    drop_table :counties_simplified_01
  end
end
