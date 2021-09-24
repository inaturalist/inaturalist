# Load time zone geometries from a GeoJSON file of timezones with oceans
# obtained from https://github.com/evansiroky/timezone-boundary-builder/releases
# This will overwrite the table in the existing database
#
# Usage:
#  rails r tools/load_time_zone_geometries.rb /path/to/combined-with-oceans.geojson
#
table_name = TimeZoneGeometry.table_name
pg_string = {
  dbname: ApplicationRecord.connection_config[:database],
  host: ApplicationRecord.connection_config[:host],
  user: ApplicationRecord.connection_config[:username],
  password: ApplicationRecord.connection_config[:password],
}.map { |k,v| "#{k}=#{v}" }.join( " " )

unless File.exists?( ARGV[0] )
  puts "No file at #{ARGV[0]}"
  exit 0
end

# Note that ogr2ogr will automatically create a spatial index on the geom column
cmd = <<-BASH
  ogr2ogr -f "PostgreSQL" PG:"#{pg_string}" \
    #{ARGV[0]} \
    -nln #{table_name} \
    -lco GEOMETRY_NAME=geom \
    -overwrite
BASH
puts "Loading time zones..."
system cmd

# By default the SRID is 4326, and all ours are 0 for some reason
puts "Resetting SRID..."
ActiveRecord::Base.connection.execute "SELECT UpdateGeometrySRID('#{table_name}', 'geom', 0)"
