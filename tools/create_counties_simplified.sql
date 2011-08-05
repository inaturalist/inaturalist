-- Create table of simplified county shapes.  Run this on prod data but not 
-- on a webserver.  It will gobble memory.  There are a lot of counties.
DROP TABLE IF EXISTS counties_simplified;
CREATE TABLE counties_simplified (
  id INTEGER,
  place_id INTEGER);
SELECT AddGeometryColumn('counties_simplified', 'geom', -1, 'MULTIPOLYGON', 2);

INSERT INTO counties_simplified
SELECT 
  place_geometries.id, 
  place_id,
  multi(cleangeometry(ST_SimplifyPreserveTopology(geom, 0.01))) as geom
FROM 
  place_geometries
    INNER JOIN places ON places.id = place_geometries.place_id 
WHERE places.place_type = 9
