# Contains a time zone geometry as defined by
# https://github.com/evansiroky/timezone-boundary-builder/releases
class TimeZoneGeometry < ActiveRecord::Base
  class << self
    def tzid_for_lat_lng( lat, lng )
      TimeZoneGeometry.select("tzid").
        where( "st_intersects(geom, st_point(?, ?))", lng, lat ).
        first.try(:tzid)
    end
    alias_method :tzid_from_lat_lng, :tzid_for_lat_lng

    def time_zone_for_lat_lng( lat, lng )
      if tzid = TimeZoneGeometry.tzid_for_lat_lng( lat, lng )
        ActiveSupport::TimeZone[tzid]
      end
    end
    alias_method :time_zone_from_lat_lng, :time_zone_for_lat_lng

    def load_geojson_file( geojson_path, options = {} )
      logger = options[:logger] || Rails.logger
      return unless File.exist?( geojson_path )
      pg_string = {
        dbname: ApplicationRecord.connection_db_config.configuration_hash[:database],
        host: ApplicationRecord.connection_db_config.configuration_hash[:host],
        user: ApplicationRecord.connection_db_config.configuration_hash[:username],
        password: ApplicationRecord.connection_db_config.configuration_hash[:password],
      }.map { |k, v| "#{k}=#{v}" }.join( " " )
      # Note that ogr2ogr will automatically create a spatial index on the geom column
      cmd = <<-BASH
        ogr2ogr -f "PostgreSQL" PG:"#{pg_string}" \
          #{geojson_path} \
          -nln #{table_name} \
          -nlt MULTIPOLYGON \
          -lco GEOMETRY_NAME=geom \
          -overwrite
      BASH
      logger.info "Loading time zones..."
      if system( cmd ) && TimeZoneGeometry.count > 0
        logger.info "Loaded #{TimeZoneGeometry.count} time zones with ogr2ogr"
      else
        logger.info "ogr2ogr failed for some reason, try to load and process with RGeo instead"
        File.open( geojson_path ) do |f|
          logger.info "Reading GeoJSON from #{geojson_path}..."
          json = RGeo::GeoJSON.decode( f.read )
          TimeZoneGeometry.transaction do
            logger.info "Truncating #{table_name}..."
            TimeZoneGeometry.connection.execute( "TRUNCATE TABLE #{table_name} RESTART IDENTITY" )
            logger.info "Loading #{json.size} time zones"
            json.each do |zone|
              print "." if options[:debug]
              geom = if zone.geometry.geometry_type == ::RGeo::Feature::Polygon
                factory = RGeo::Cartesian.simple_factory( srid: 0 )
                factory.multi_polygon( [zone.geometry] )
              else
                zone.geometry
              end
              TimeZoneGeometry.create!( tzid: zone.properties["tzid"], geom: geom )
            end
            logger.info
          end
        end
        logger.info "Loaded #{TimeZoneGeometry.count} time zones with RGeo"
      end

      # By default the SRID is 4326, and all ours are 0 for some reason
      logger.info "Resetting SRID..."
      ActiveRecord::Base.connection.execute "SELECT UpdateGeometrySRID('#{table_name}', 'geom', 0)"
    end

    def load_shapefile( shp_path, options = {} )
      logger = options[:logger] || Rails.logger
      raise "Shapefile does not exist at #{shp_path}" unless File.exist?( shp_path )
      pg_string = {
        dbname: ApplicationRecord.connection_db_config.configuration_hash[:database],
        host: ApplicationRecord.connection_db_config.configuration_hash[:host],
        user: ApplicationRecord.connection_db_config.configuration_hash[:username],
        password: ApplicationRecord.connection_db_config.configuration_hash[:password],
      }.map { |k, v| "#{k}=#{v}" }.join( " " )
      # Note that ogr2ogr will automatically create a spatial index on the geom column
      cmd = <<-BASH
        ogr2ogr -f "PostgreSQL" PG:"#{pg_string}" \
          #{shp_path} \
          -nln #{table_name} \
          -nlt MULTIPOLYGON \
          -lco GEOMETRY_NAME=geom \
          -overwrite
      BASH
      logger.info "Loading time zones..."
      if system( cmd ) && TimeZoneGeometry.count > 0
        logger.info "Loaded #{TimeZoneGeometry.count} time zones with ogr2ogr"
      else
        logger.info "ogr2ogr failed for some reason, try to load and process with RGeo instead"
        RGeo::Shapefile::Reader.open( shp_path ) do | file |
          logger.info "Reading time zones from #{shp_path}..."
          TimeZoneGeometry.transaction do
            file.each do | zone |
              print "." if options[:debug]
              geom = if zone.geometry.geometry_type == ::RGeo::Feature::Polygon
                factory = RGeo::Cartesian.simple_factory( srid: 0 )
                factory.multi_polygon( [zone.geometry] )
              else
                zone.geometry
              end
              TimeZoneGeometry.create!( tzid: zone.attributes["tzid"], geom: geom )
            end
            logger.info
          end
          logger.info "Loaded #{TimeZoneGeometry.count} time zones with RGeo"
        end
      end
      # By default the SRID is 4326, and all ours are 0 for some reason
      logger.info "Resetting SRID..."
      ActiveRecord::Base.connection.execute "SELECT UpdateGeometrySRID('#{table_name}', 'geom', 0)"
    end
  end
end
