class AddPlaceIdIndexOnPlaceGeometries < ActiveRecord::Migration
  def self.up
    add_index :place_geometries, :place_id
  end

  def self.down
    drop_index :place_geometries, :place_id
  end
end
