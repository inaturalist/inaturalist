# frozen_string_literal: true

require "spec_helper"

describe MetaService do
  describe ".fetch_request_uri" do
    let( :api_endpoint ) do
      ApiEndpoint.make!( base_url: "https://example.com/api?", cache_hours: 720 )
    end
    let( :request_uri ) { URI.parse( "https://example.com/api?page=Animalia" ) }

    def stub_fetch( code:, body: )
      response = double( "Net::HTTPResponse", code: code.to_s, body: body )
      allow( MetaService ).to receive( :fetch_with_redirects ).and_return( response )
      response
    end

    def cache_for( uri = request_uri )
      ApiEndpointCache.find_by( api_endpoint: api_endpoint, request_url: uri.to_s )
    end

    it "stores the status code and parses a normal response" do
      stub_fetch( code: 200, body: "<parse><text>ok</text></parse>" )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      cache = cache_for
      expect( cache.status_code ).to eq 200
      expect( cache.success ).to be true
      expect( cache.throttled_at ).to be_nil
      expect( cache.recently_throttled? ).to be false
    end

    it "records a throttle and returns nil when there is nothing cached to serve" do
      stub_fetch( code: 429, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_nil
      cache = cache_for
      expect( cache.status_code ).to eq 429
      expect( cache.recently_throttled? ).to be true
      # a throttle is never recorded as a usable, successful response
      expect( cache.usable_response? ).to be false
    end

    it "treats a too-many-requests body as throttled even with a 200 status" do
      stub_fetch( code: 200, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint,
        raw_response: true )
      expect( result ).to be_nil
      cache = cache_for
      expect( cache.recently_throttled? ).to be true
      expect( cache.usable_response? ).to be false
    end

    it "does not overwrite a previously cached success with a throttle, and keeps serving it" do
      # An expired-but-valid 200 (older than cache_hours) so the fetch path runs.
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 200, success: true, response: "<parse><text>cached ok</text></parse>",
        request_began_at: 721.hours.ago, request_completed_at: 721.hours.ago )
      stub_fetch( code: 429, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      # the good cached body is served, not the throttle message
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( result.at( "text" ).text ).to eq "cached ok"
      cache = cache_for
      expect( cache.response ).to eq "<parse><text>cached ok</text></parse>"
      expect( cache.success ).to be true
      expect( cache.status_code ).to eq 429
      expect( cache.recently_throttled? ).to be true
    end

    it "serves the cached success without re-fetching while throttled" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 200, success: true, response: "<parse><text>cached ok</text></parse>",
        request_began_at: 721.hours.ago, request_completed_at: 721.hours.ago,
        throttled_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result.at( "text" ).text ).to eq "cached ok"
    end

    it "returns nil for a throttled response with nothing cached, without re-fetching" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 429, success: false, throttled_at: 1.minute.ago,
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_nil
    end

    it "re-fetches once the throttle retry window has passed" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 429, success: false,
        throttled_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago,
        request_began_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago,
        request_completed_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
      stub_fetch( code: 200, body: "<parse><text>ok</text></parse>" )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      cache = cache_for
      expect( cache.success ).to be true
      expect( cache.throttled_at ).to be_nil
    end
  end
end
