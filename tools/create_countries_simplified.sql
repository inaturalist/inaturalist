-- create table of places larger than a threshold
DROP TABLE IF EXISTS countries_large_polygons;
CREATE TABLE countries_large_polygons AS
SELECT MAX(id) AS id, MAX(place_id) AS place_id, ST_Collect(geom) as geom
FROM (
  SELECT place_geometries.id, place_geometries.place_id, (ST_Dump(geom)).geom
  FROM place_geometries JOIN places ON places.id = place_geometries.place_id
  WHERE places.place_type = 12) AS foo
WHERE ST_Area(geom) > 1
GROUP BY id;

-- create table of simplified shapes
DROP TABLE IF EXISTS countries_simplified;
CREATE TABLE countries_simplified (
  id INTEGER,
  place_id INTEGER);
SELECT AddGeometryColumn('countries_simplified', 'geom', -1, 'MULTIPOLYGON', 2);

INSERT INTO countries_simplified 
  (id, place_id, geom) 
SELECT 
  countries_large_polygons.id, 
  place_id, 
  multi(cleangeometry(ST_SimplifyPreserveTopology(geom, 0.1)))
FROM 
  countries_large_polygons;

GRANT SELECT ON countries_simplified TO readonly;
