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
  password: ApplicationRecord.connection_config[:password]
}.map { |k, v| "#{k}=#{v}" }.join( " " )

unless File.exist?( ARGV[0] )
  puts "No file at #{ARGV[0]}"
  exit 0
end

# Note that ogr2ogr will automatically create a spatial index on the geom column
cmd = <<-BASH
  ogr2ogr -f "PostgreSQL" PG:"#{pg_string}" \
    #{ARGV[0]} \
    -nln #{table_name} \
    -nlt MULTIPOLYGON \
    -lco GEOMETRY_NAME=geom \
    -overwrite
BASH
puts "Loading time zones..."
if false && system( cmd ) && TimeZoneGeometry.count > 0
  puts "Loaded #{TimeZoneGeometry.count} time zones with ogr2ogr"
else
  puts "ogr2ogr failed for some reason, try to load and process with RGeo instead"
  File.open( ARGV[0] ) do |f|
    puts "Reading GeoJSON from #{ARGV[0]}..."
    json = RGeo::GeoJSON.decode( f.read )
    TimeZoneGeometry.transaction do
      puts "Truncating #{table_name}..."
      TimeZoneGeometry.connection.execute( "TRUNCATE TABLE #{table_name} RESTART IDENTITY" )
      puts "Loading #{json.size} time zones"
      json.each do |zone|
        print "."
        geom = if zone.geometry_type == ::RGeo::Feature::MultiPolygon
          factory = RGeo::Cartesian.simple_factory( srid: 0 )
          factory.multi_polygon( [zone.geometry] )
        else
          zone.geometry
        end
        TimeZoneGeometry.create!( tzid: zone.properties["tzid"], geom: geom )
      end
      puts
    end
  end
  puts "Loaded #{TimeZoneGeometry.count} time zones with RGeo"
end

# By default the SRID is 4326, and all ours are 0 for some reason
puts "Resetting SRID..."
ActiveRecord::Base.connection.execute "SELECT UpdateGeometrySRID('#{table_name}', 'geom', 0)"
