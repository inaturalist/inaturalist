# frozen_string_literal: true

require "spec_helper"

describe MetaService do
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

  describe "#user_agent" do
    it "passes the class-specific user agent to fetch_with_redirects" do
      service = WikipediaService.new
      expected_user_agent = "#{Site.default.name}/1 " \
        "(#{Site.default.url}; #{CONFIG.meta_service_email}) " \
        "WikipediaService/Rails/1"
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

    it "passes just sitename to fetch_with_redirects from fetch_request_uri" do
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

  describe ".fetch_request_uri when the endpoint is throttling us" do
    let( :good_response ) { "<parse><text>ok</text></parse>" }

    def make_expired_good_cache( uri = request_uri )
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: uri.to_s,
        status_code: 200, success: true, response: good_response,
        request_began_at: ( api_endpoint.cache_hours + 1 ).hours.ago,
        request_completed_at: ( api_endpoint.cache_hours + 1 ).hours.ago )
    end

    it "does not send a request and returns nil" do
      api_endpoint.update( last_throttled_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_nil
    end

    it "leaves an expired cached response intact instead of overwriting it with a throttle body" do
      cache = make_expired_good_cache
      api_endpoint.update( last_throttled_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      cache.reload
      expect( cache.response ).to eq good_response
      expect( cache.success ).to be true
      expect( cache.status_code ).to eq 200
    end

    it "blocks requests for every cache row, whatever state that row is in" do
      cold_uri = URI.parse( "https://example.com/api?page=Fungi" )
      expired_uri = URI.parse( "https://example.com/api?page=Plantae" )
      lapsed_429_uri = URI.parse( "https://example.com/api?page=Protozoa" )
      make_expired_good_cache( expired_uri )
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: lapsed_429_uri.to_s,
        status_code: 429, success: false, response: "You are making too many requests.",
        request_began_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago,
        request_completed_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
      api_endpoint.update( last_throttled_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      [cold_uri, expired_uri, lapsed_429_uri].each do | uri |
        MetaService.fetch_request_uri( request_uri: uri, api_endpoint: api_endpoint )
      end
      [cold_uri, lapsed_429_uri].each do | uri |
        expect(
          MetaService.fetch_request_uri( request_uri: uri, api_endpoint: api_endpoint )
        ).to be_nil
      end
    end

    it "serves an expired cached response rather than nothing" do
      make_expired_good_cache
      api_endpoint.update( last_throttled_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( result.at( "text" ).inner_text ).to eq "ok"
    end

    it "still serves a fresh cached response" do
      ApiEndpointCache.make!( api_endpoint: api_endpoint, request_url: request_uri.to_s,
        status_code: 200, success: true, response: good_response,
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      api_endpoint.update( last_throttled_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( result.at( "text" ).inner_text ).to eq "ok"
    end

    it "suppresses a forced refresh too, so it cannot destroy a cached response" do
      cache = make_expired_good_cache
      api_endpoint.update( last_throttled_at: 1.minute.ago )
      expect( MetaService ).not_to receive( :fetch_with_redirects )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint,
        force_update: true )
      expect( result ).to be_nil
      expect( cache.reload.response ).to eq good_response
    end

    it "resumes fetching once the throttle window has passed" do
      api_endpoint.update(
        last_throttled_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago
      )
      stub_fetch( code: 200, body: good_response )
      result = MetaService.fetch_request_uri( request_uri: request_uri, api_endpoint: api_endpoint )
      expect( result ).to be_a( Nokogiri::XML::Document )
      expect( cache_for.success ).to be true
    end
  end
end
