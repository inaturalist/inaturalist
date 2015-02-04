class AddPostGisColumns < ActiveRecord::Migration
  def self.up
    remove_column :place_geometries, :geom
    add_column :place_geometries, :geom, :multi_polygon, :null => false
    add_index :place_geometries, :geom, :spatial => true
    
    add_column :observations, :geom, :point
    add_index :observations, :geom, :spatial => true
    Observation.where("latitude IS NOT NULL").update_all("geom = ST_Point(longitude, latitude)")
  end

  def self.down
    # this will destroy data!
    remove_column :place_geometies, :geom
    add_column :place_geometies, :geom, :text
    
    remove_column :observations, :geom
  end
end
