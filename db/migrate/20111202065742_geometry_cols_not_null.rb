class GeometryColsNotNull < ActiveRecord::Migration
  def self.up
    execute "DELETE FROM place_geometries WHERE geom IS NULL"
    execute "ALTER TABLE place_geometries ALTER COLUMN geom SET not null"
  end

  def self.down
    execute "ALTER TABLE place_geometries ALTER COLUMN geom DROP not null"
  end
end
