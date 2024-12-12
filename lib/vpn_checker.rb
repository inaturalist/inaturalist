# frozen_string_literal: true

class VPNChecker
  CACHE_KEY = "vpn_ips"

  def initialize( cache_expiry = 1.day )
    @cache_expiry = cache_expiry
    @url = CONFIG.vpn_ips_url
  end

  def ip_in_vpn_range?( ip )
    begin
      ip_addr = IPAddr.new( ip )
    rescue IPAddr::InvalidAddressError
      return false
    end
    vpn_ranges = load_vpn_ranges
    vpn_ranges.any? {| range | range.include?( ip_addr ) }
  end

  private

  def load_vpn_ranges
    Rails.cache.fetch( CACHE_KEY, expires_in: @cache_expiry ) do
      fetch_vpn_ranges_from_url
    end
  end

  def fetch_vpn_ranges_from_url
    response = fetch_url_content
    return [] if response.nil?

    parse_ip_ranges( response )
  end

  def fetch_url_content
    begin
      uri = URI( @url )
      response = Net::HTTP.get( uri )

      if response.nil? || response.strip.empty?
        Rails.logger.error( "VPN range data is empty or invalid." )
        return nil
      end

      response
    rescue StandardError => e
      Rails.logger.error( "Error fetching VPN range data from URL: #{e.message}" )
      nil
    end
  end

  def parse_ip_ranges( response )
    response.split( "\n" ).map( &:strip ).select do | range |
      begin
        IPAddr.new( range )
      rescue IPAddr::InvalidAddressError
        nil
      end
    end.compact.map {| range | IPAddr.new( range ) }
  end
end
