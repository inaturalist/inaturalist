class AddPrivateGeomToObservations < ActiveRecord::Migration
  def up
    execute "SELECT AddGeometryColumn('observations','private_geom',-1,'POINT',2,true)"
    add_index :observations, :private_geom, :spatial => true
    execute "UPDATE observations SET private_geom = (CASE WHEN private_latitude IS NULL THEN geom ELSE ST_Point(private_longitude, private_latitude) END)"
  end
  def down
    remove_column :observations, :private_geom
  end
end
