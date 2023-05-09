class CreateTimeZoneGeometries < ActiveRecord::Migration[4.2]
  def change
    create_table :time_zone_geometries, id: false do |t|
      t.string :tzid
      t.multi_polygon :geom
    end
    # FYI, we will generally be loading time zone boundaries using ogr2ogr,
    # which should add a spatial index automatically
  end
end
