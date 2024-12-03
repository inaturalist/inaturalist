# frozen_string_literal: true

require "ipaddr"
require "net/http"
require "uri"

class VPNChecker
  CACHE_KEY = "vpn_ips"
  URL = "https://raw.githubusercontent.com/X4BNet/lists_vpn/main/ipv4.txt"

  def initialize( cache_expiry = 1.day )
    @cache_expiry = cache_expiry
  end

  def ip_in_vpn_range?( ip )
    vpn_ranges = load_vpn_ranges
    ip_addr = IPAddr.new( ip )
    vpn_ranges.any? {| range | range.include?( ip_addr ) }
  end

  private

  def load_vpn_ranges
    Rails.cache.fetch(CACHE_KEY, expires_in: @cache_expiry) do
      fetch_vpn_ranges_from_url
    end
  end

  def fetch_vpn_ranges_from_url
    uri = URI( URL )
    response = Net::HTTP.get( uri )
    response.split( "\n" ).map( &:strip ).map {| range | IPAddr.new( range ) }
  end
end
