# frozen_string_literal: true

class CleanPlaceGeometriesAndTaxonRanges < ActiveRecord::Migration[6.1]
  def up
    add_column :place_geometries, :cleaned_geom, :geometry
    add_column :taxon_ranges, :cleaned_geom, :geometry

    [:place_geometries, :taxon_ranges].each do | table_name |
      # update lngs of geoms where all lngs are out of bounds
      execute <<-SQL
        UPDATE #{table_name}
        SET cleaned_geom = ST_Translate(
          geom,
          -360 * FLOOR((ST_XMin(geom) + 180) / 360),
          0
        )
        WHERE geom IS NOT NULL
          AND cleaned_geom IS NULL
          AND ST_GeometryType(geom) IN ('ST_Polygon', 'ST_MultiPolygon')
          AND (
            ST_XMax(geom) < -180
            OR ST_XMin(geom) > 180
          )
      SQL

      # clean geoms where some lngs are out of bounds
      execute <<-SQL
        UPDATE #{table_name}
        SET cleaned_geom = ST_Multi(
          ST_CollectionExtract(
            ST_MakeValid(
              ST_Intersection(
                geom,
                ST_MakeEnvelope(-179.999999, -90, 179.999999, 90)
              )
            ),
            3
          )
        )
        WHERE geom IS NOT NULL
          AND cleaned_geom IS NULL
          AND ST_GeometryType(geom) IN ('ST_Polygon', 'ST_MultiPolygon')
          AND (
            ST_XMax(geom) > 180
            OR ST_XMin(geom) < -180
          )
      SQL

      # replace original geoms with cleaned versions
      execute <<-SQL
        UPDATE #{table_name}
        SET geom = cleaned_geom
        WHERE cleaned_geom IS NOT NULL
          AND NOT ST_IsEmpty(cleaned_geom)

      SQL
    end

    remove_column :place_geometries, :cleaned_geom
    remove_column :taxon_ranges, :cleaned_geom
  end

  def down
    # irreversible
  end
end
