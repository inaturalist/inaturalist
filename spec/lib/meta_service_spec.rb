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
      expect( cache.throttled? ).to be false
    end

    it "marks a fresh 429 response as throttled, not a success, and returns nil when nothing is cached" do
      stub_fetch( code: 429, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_nil
      cache = cache_for
      expect( cache.status_code ).to eq 429
      expect( cache.success ).to be_falsey
      expect( cache.throttled? ).to be true
      # the throttle body is not persisted; it is logged to Logstasher instead
      expect( cache.response ).to be_blank
    end

    it "treats a too-many-requests body as throttled even with a 200 status" do
      stub_fetch( code: 200, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint,
        raw_response: true )
      expect( result ).to be_nil
      cache = cache_for
      expect( cache.success ).to be_falsey
      expect( cache.throttled? ).to be true
    end

    it "returns nil for a cached throttled response with nothing usable, without re-fetching" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 429, success: false, response: nil,
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_nil
    end

    it "serves the previously cached response while throttled, without re-fetching" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 429, success: true, response: "<parse><text>stale but ok</text></parse>",
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( result.at( "text" ).inner_text ).to eq "stale but ok"
    end

    it "keeps and serves the previously cached response when a fresh fetch is throttled" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 200, success: true, response: "<parse><text>stale but ok</text></parse>",
        request_began_at: ( api_endpoint.cache_hours + 1 ).hours.ago,
        request_completed_at: ( api_endpoint.cache_hours + 1 ).hours.ago )
      stub_fetch( code: 429, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( result.at( "text" ).inner_text ).to eq "stale but ok"
      cache = cache_for
      expect( cache.throttled? ).to be true
      expect( cache.success ).to be true
      expect( cache.response ).to eq "<parse><text>stale but ok</text></parse>"
    end

    it "re-fetches a throttled response once the retry window has passed" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 429, success: false, response: nil,
        request_began_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago,
        request_completed_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
      stub_fetch( code: 200, body: "<parse><text>ok</text></parse>" )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( cache_for.success ).to be true
    end
  end
end
