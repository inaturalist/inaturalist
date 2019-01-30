class AddPrivateGeomToObservations < ActiveRecord::Migration
  def up
    begin
      execute "SELECT AddGeometryColumn('observations'::varchar,'private_geom'::varchar,-1,'POINT'::varchar,2,true)"
    rescue PG::Error
      execute "SELECT AddGeometryColumn('observations'::varchar,'private_geom'::varchar,-1,'POINT'::varchar,2)"
    end
    add_index :observations, :private_geom, :spatial => true
    execute "UPDATE observations SET private_geom = (CASE WHEN private_latitude IS NULL THEN geom ELSE ST_Point(private_longitude, private_latitude) END)"
  end
  def down
    remove_column :observations, :private_geom
  end
end
