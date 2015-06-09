class CreateCleangeometryFunction < ActiveRecord::Migration
  def up
    ActiveRecord::Base.connection.execute('
      DROP FUNCTION IF EXISTS cleangeometry(geom "public"."geometry")')
    ActiveRecord::Base.connection.execute("
      -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      --
      -- $Id: cleanGeometry.sql 2014-01-16 Paul Pfeiffer
      --
      -- cleanGeometry - remove self- and ring-selfintersections from
      --                 input Polygon geometries
      --
      -- Copyright 2014 Paul Pfeiffer
      -- Version 2.0
      -- contact: nightdrift at gmail dot com
      --
      -- modified from cleanGeometry.sql 2008-04-24 from http://www.kappasys.ch
      --
      -- This is free software; you can redistribute and/or modify it under
      -- the terms of the GNU General Public Licence. See the COPYING file.
      -- This software is without any warrenty and you use it at your own risk
      --
      -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


      CREATE OR REPLACE FUNCTION cleangeometry(geom \"public\".\"geometry\")
          RETURNS \"public\".\"geometry\" AS
      $BODY$
          DECLARE
          inGeom ALIAS for $1;
          outGeom geometry;
          tmpLinestring geometry;
          sqlString text;

      BEGIN

          outGeom := NULL;

          -- Clean Polygons --
          IF (ST_GeometryType(inGeom) = 'ST_Polygon' OR ST_GeometryType(inGeom) = 'ST_MultiPolygon') THEN

              -- Check if it needs fixing
              IF NOT ST_IsValid(inGeom) THEN

                  sqlString := '
                      -- separate multipolygon into 1 polygon per row
                      WITH split_multi (geom, poly) AS (
                          SELECT
                              (ST_Dump($1)).geom,
                              (ST_Dump($1)).path[1] -- polygon number
                      ),
                      -- break each polygon into linestrings
                      split_line (geom, poly, line) AS (
                          SELECT
                              ST_Boundary((ST_DumpRings(geom)).geom),
                              poly,
                              (ST_DumpRings(geom)).path[1] -- line number
                          FROM split_multi
                      ),
                      -- get the linestrings that make up the exterior of each polygon
                      line_exterior (geom, poly) AS (
                          SELECT
                              geom,
                              poly
                          FROM split_line
                          WHERE line = 0
                      ),
                      -- get an array of all the linestrings that make up the interior of each polygon
                      line_interior (geom, poly) AS (
                          SELECT
                              array_agg(geom ORDER BY line),
                              poly
                          FROM split_line
                          WHERE line > 0
                          GROUP BY poly
                      ),
                      -- use MakePolygon to rebuild the polygons
                      poly_geom (geom, poly) AS (
                          SELECT
                              CASE WHEN line_interior.geom IS NULL
                                  THEN ST_Buffer(ST_MakePolygon(line_exterior.geom), 0)
                                  ELSE ST_Buffer(ST_MakePolygon(line_exterior.geom, line_interior.geom), 0)
                              END,
                              line_exterior.poly
                          FROM line_exterior
                          LEFT JOIN line_interior USING (poly)
                      )
                  ';

                  IF (ST_GeometryType(inGeom) = 'ST_Polygon') THEN
                      sqlString := sqlString || '
                          SELECT geom
                          FROM poly_geom
                      ';
                  ELSE
                      sqlString := sqlString || '
                          , -- if its a multipolygon combine the polygons back together
                          multi_geom (geom) AS (
                              SELECT
                                  ST_Multi(ST_Collect(geom ORDER BY poly))
                              FROM poly_geom
                          )
                          SELECT geom
                          FROM multi_geom
                      ';
                  END IF;

                  EXECUTE sqlString INTO outGeom USING inGeom;

                  RETURN outGeom;
              ELSE
                  RETURN inGeom;
              END IF;

          -- Clean Lines --
          ELSIF (ST_GeometryType(inGeom) = 'ST_Linestring') THEN

              outGeom := ST_Union(ST_Multi(inGeom), ST_PointN(inGeom, 1));
              RETURN outGeom;
          ELSIF (ST_GeometryType(inGeom) = 'ST_MultiLinestring') THEN
              outGeom := ST_Multi(ST_Union(ST_Multi(inGeom), ST_PointN(inGeom, 1)));
              RETURN outGeom;
          ELSE
              RAISE NOTICE 'The input type % is not supported',ST_GeometryType(inGeom);
              RETURN inGeom;
          END IF;
      END;
      $BODY$
      LANGUAGE 'plpgsql' VOLATILE COST 100")
  end

  def down
    ActiveRecord::Base.connection.execute('
      DROP FUNCTION IF EXISTS cleangeometry(geom "public"."geometry")')
  end

end
