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
  end
end
