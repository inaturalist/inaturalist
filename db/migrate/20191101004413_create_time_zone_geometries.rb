class CreateTimeZoneGeometries < ActiveRecord::Migration
  def change
    create_table :time_zone_geometries, id: false do |t|
      t.string :tzid
      t.multi_polygon :geom
    end
    add_index :time_zone_geometries, :geom, spatial: true
  end
end
