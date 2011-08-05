-- create table of places larger than a threshold
DROP TABLE IF EXISTS states_large_polygons;
CREATE TABLE states_large_polygons AS
SELECT MAX(id) AS id, MAX(place_id) AS place_id, ST_Collect(geom) as geom
FROM (
  SELECT place_geometries.id, place_geometries.place_id, (ST_Dump(geom)).geom
  FROM place_geometries JOIN places ON places.id = place_geometries.place_id
  WHERE places.place_type = 8) AS foo
WHERE ST_Area(geom) > 0.1
GROUP BY id;

-- create table of simplified shapes
DROP TABLE IF EXISTS states_simplified;
CREATE TABLE states_simplified (
  id INTEGER,
  place_id INTEGER);
SELECT AddGeometryColumn('states_simplified', 'geom', -1, 'MULTIPOLYGON', 2);

INSERT INTO states_simplified 
  (id, place_id, geom) 
SELECT 
  states_large_polygons.id, 
  place_id, 
  multi(cleangeometry(ST_SimplifyPreserveTopology(geom, 0.05)))
FROM 
  states_large_polygons;

GRANT SELECT ON states_simplified TO readonly;
