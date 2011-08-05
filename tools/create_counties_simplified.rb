max = Place.count(:conditions => {:place_type => 9})
step = 1000
puts "Re-creating table counties_simplified..."
ActiveRecord::Base.connection.execute <<-SQL
  DROP TABLE IF EXISTS counties_simplified;
  CREATE TABLE counties_simplified (
    id INTEGER,
    place_id INTEGER);
  SELECT AddGeometryColumn('counties_simplified', 'geom', -1, 'MULTIPOLYGON', 2);
SQL

(max.to_f / step).ceil.times do |i|
  offset = i * step
  puts "#{offset + 1} - #{offset + step}"
  ActiveRecord::Base.connection.execute <<-SQL
    INSERT INTO counties_simplified
    SELECT 
      place_geometries.id, 
      place_id, 
      multi(cleangeometry(ST_SimplifyPreserveTopology(geom, 0.01))) as geom
    FROM 
      place_geometries
        INNER JOIN places ON places.id = place_geometries.place_id 
    WHERE places.place_type = 9
    LIMIT #{step}
    OFFSET #{offset};
  SQL
end
