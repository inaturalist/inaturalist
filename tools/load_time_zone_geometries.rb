# Load time zone geometries from a GeoJSON file of timezones with oceans
# obtained from https://github.com/evansiroky/timezone-boundary-builder/releases
# This will overwrite the table in the existing database
#
# Usage:
#  rails r tools/load_time_zone_geometries.rb /path/to/combined-with-oceans.geojson
#

unless File.exist?( ARGV[0] )
  puts "No file at #{ARGV[0]}"
  exit 0
end

TimeZoneGeometry.load_geojson_file(
  ARGV[0],
  logger: Logger.new( STDOUT ),
  debug: true
)
