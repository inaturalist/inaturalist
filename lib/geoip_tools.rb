module GeoipTools
  IP_PATTERN = /([0-9A-z]{1,3}\.?){4}/
  
  def self.city(ip)
    return nil unless ip.match IP_PATTERN
    results = GEOIP.city(ip)
    {
      :ip => results[0],
      :ip2 => results[1],
      :country_code => results[2],
      :country_abbrev => results[3],
      :country => results[4],
      :contenent_code => results[5],
      :state_code => results[6],
      :city => results[7],
      :something_else => results[8],
      :latitude => results[9],
      :longitude => results[10],
      :something_else => results[11],
      :area_code => results[12]
    }
  end
end