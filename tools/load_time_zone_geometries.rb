# Load time zone geometries from a GeoJSON file of timezones with oceans
# obtained from https://github.com/evansiroky/timezone-boundary-builder/releases
# This will overwrite the table in the existing database
#
# Usage:
#  rails r tools/load_time_zone_geometries.rb /path/to/combined-with-oceans.geojson

filename = ARGV[0]

unless File.exist?( filename )
  abort "No file at #{filename}"
end

case File.extname( filename )
when ".shp"
  TimeZoneGeometry.load_shapefile(
    filename,
    logger: Logger.new( STDOUT ),
    debug: true
  )
when ".json", ".geojson"
  TimeZoneGeometry.load_geojson_file(
    filename,
    logger: Logger.new( STDOUT ),
    debug: true
  )
else
  abort "Don't know how to load file #{filename}"
end
