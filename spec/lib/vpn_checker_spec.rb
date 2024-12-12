require "spec_helper"

describe VPNChecker do
  let( :vpn_ips_url ) { "http://example.com/vpn_ips" }
  let( :vpn_checker ) { VPNChecker.new }

  before do
    allow( CONFIG ).to receive( :vpn_ips_url ).and_return vpn_ips_url
    Rails.cache.clear
  end

  describe "check when ip" do
    before do
      allow( vpn_checker ).to receive( :fetch_url_content ).and_return( "192.168.1.1\n192.168.0.0/24\n10.0.0.0/8" )
    end

    it "is within a VPN range" do
      expect( vpn_checker.ip_in_vpn_range?( "192.168.1.1" ) ).to be true
      expect( vpn_checker.ip_in_vpn_range?( "192.168.0.1" ) ).to be true
    end

    it "is not within a VPN range" do
      expect( vpn_checker.ip_in_vpn_range?( "8.8.8.8" ) ).to be false
      expect( vpn_checker.ip_in_vpn_range?( "192.168.1.2" ) ).to be false
    end

    it "is invalid" do
      expect( vpn_checker.ip_in_vpn_range?( "555.555.555.555" ) ).to be false
    end
  end

  describe "check cache" do
    let( :vpn_checker_with_short_cache ) { described_class.new( 2.seconds ) }
    let( :ip_range1 ) { "192.168.1.1" }
    let( :ip_range2 ) { "192.168.2.2" }

    it "is active" do
      allow( vpn_checker_with_short_cache ).to receive( :fetch_url_content ).and_return( ip_range1 )
      ranges = vpn_checker_with_short_cache.send( :load_vpn_ranges )
      expect( ranges.first.to_s ).to eq( ip_range1 )
      allow( vpn_checker_with_short_cache ).to receive( :fetch_url_content ).and_return( ip_range2 )
      ranges = vpn_checker_with_short_cache.send( :load_vpn_ranges )
      expect( ranges.first.to_s ).to eq( ip_range1 )
    end

    it "has expiration" do
      allow( vpn_checker_with_short_cache ).to receive( :fetch_url_content ).and_return( ip_range1 )
      ranges = vpn_checker_with_short_cache.send( :load_vpn_ranges )
      expect( ranges.first.to_s ).to eq( ip_range1 )
      sleep( 5 )
      allow( vpn_checker_with_short_cache ).to receive( :fetch_url_content ).and_return( ip_range2 )
      ranges = vpn_checker_with_short_cache.send( :load_vpn_ranges )
      expect( ranges.first.to_s ).to eq( ip_range2 )
    end
  end

  describe "fetch URL content" do
    let( :response_body ) { "192.168.0.0/24\n10.0.0.0/8" }

    it "fetches the content from the configured URL" do
      stub_request( :get, vpn_ips_url ).to_return( body: response_body, status: 200 )
      expect( vpn_checker.send( :fetch_url_content ) ).to eq( response_body )
    end

    it "logs an error and returns nil if the response is empty" do
      stub_request( :get, vpn_ips_url ).to_return( body: "", status: 200 )
      expect( Rails.logger ).to receive( :error )
      expect( vpn_checker.send( :fetch_url_content ) ).to be_nil
    end

    it "logs an error and returns nil if an exception occurs" do
      allow( Net::HTTP ).to receive( :get ).and_raise( StandardError.new( "connection error" ) )
      expect( Rails.logger ).to receive( :error )
      expect( vpn_checker.send( :fetch_url_content ) ).to be_nil
    end
  end

  describe "parse VPN ranges" do
    it "parses valid IP ranges into IPAddr objects" do
      ranges = vpn_checker.send( :parse_ip_ranges, "192.168.0.1\n192.168.1.0/24\n10.0.0.0/8" )
      expect( ranges ).to all( be_a( IPAddr ) )
      expect( ranges.map( &:to_s ) ).to include( "192.168.0.1", "192.168.1.0", "10.0.0.0" )
    end

    it "ignores invalid IP ranges 1" do
      ranges = vpn_checker.send( :parse_ip_ranges, "invalid-range\n10.0.0.0/8" )
      expect( ranges ).to all( be_a( IPAddr ) )
      expect( ranges.map( &:to_s ) ).to include( "10.0.0.0" )
      expect( ranges.map( &:to_s ) ).not_to include( "invalid-range" )
    end

    it "ignores invalid IP ranges 2" do
      ranges = vpn_checker.send( :parse_ip_ranges, "555.555.555.0/24\n10.0.0.0/8" )
      expect( ranges ).to all( be_a( IPAddr ) )
      expect( ranges.map( &:to_s ) ).to include( "10.0.0.0" )
      expect( ranges.map( &:to_s ) ).not_to include( "555.555.555.0" )
    end

    it "ignores invalid IP ranges 3" do
      ranges = vpn_checker.send( :parse_ip_ranges, "555.555.555.555\n10.0.0.0/8" )
      expect( ranges ).to all( be_a( IPAddr ) )
      expect( ranges.map( &:to_s ) ).to include( "10.0.0.0" )
      expect( ranges.map( &:to_s ) ).not_to include( "555.555.555.555" )
    end
  end
end
