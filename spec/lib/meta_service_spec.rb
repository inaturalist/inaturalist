# frozen_string_literal: true

require "spec_helper"

describe MetaService do
  describe "#user_agent" do
    it "passes the class-specific user agent to fetch_with_redirects" do
      service = WikipediaService.new
      expected_user_agent = "#{Site.default.name}/1 " \
        "(#{Site.default.url}; devops@inaturalist.org) " \
        "<WikipediaService/Rails/1>"
      response = double( "Net::HTTPResponse", code: "200", body: "<parse><text>ok</text></parse>" )
      allow( MetaService ).to receive( :fetch_with_redirects ).and_return( response )
      service.parse( page: "Animalia" )
      expect( MetaService ).to have_received( :fetch_with_redirects ).
        with( hash_including( user_agent: expected_user_agent ) )
    end

    it "passes the generic user agent to fetch_with_redirects for the base service" do
      service = MetaService.new
      service.instance_variable_set( :@endpoint, "https://example.com/api?" )
      expected_user_agent = "#{Site.default.name}/MetaService/#{MetaService::SERVICE_VERSION}"
      response = double( "Net::HTTPResponse", code: "200", body: "<result>ok</result>" )
      allow( MetaService ).to receive( :fetch_with_redirects ).and_return( response )
      service.parse( page: "Animalia" )
      expect( MetaService ).to have_received( :fetch_with_redirects ).
        with( hash_including( user_agent: expected_user_agent ) )
    end
  end

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

    it "marks a 429 response as throttled, not a success, and returns nil" do
      stub_fetch( code: 429, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_nil
      cache = cache_for
      expect( cache.status_code ).to eq 429
      expect( cache.success ).to be false
      expect( cache.throttled? ).to be true
      # the throttle body is still stored for monitoring/inspection
      expect( cache.response ).to match( /too many requests/i )
    end

    it "treats a too-many-requests body as throttled even with a 200 status" do
      stub_fetch( code: 200, body: "You are making too many requests." )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint,
        raw_response: true )
      expect( result ).to be_nil
      cache = cache_for
      expect( cache.success ).to be false
      expect( cache.throttled? ).to be true
    end

    it "returns nil for a cached throttled response without re-fetching" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 429, success: false, response: "You are making too many requests.",
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_nil
    end

    it "re-fetches a throttled response once the retry window has passed" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 429, success: false, response: "You are making too many requests.",
        request_began_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago,
        request_completed_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
      stub_fetch( code: 200, body: "<parse><text>ok</text></parse>" )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( cache_for.success ).to be true
    end
  end
end
