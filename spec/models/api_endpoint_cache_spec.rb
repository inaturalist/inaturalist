require "spec_helper"

describe ApiEndpointCache do
  it { is_expected.to belong_to :api_endpoint }

  describe "in_progress?" do
    it "is true if it is in progress" do
      cache = ApiEndpointCache.make!( request_began_at: Time.now,
        request_completed_at: nil )
      expect( cache.in_progress? ).to be true
    end

    it "is false when it hasn't begun" do
      cache = ApiEndpointCache.make!( request_began_at: nil )
      expect( cache.in_progress? ).to be false
    end

    it "is false if it has completed" do
      cache = ApiEndpointCache.make!( request_began_at: Time.now,
        request_completed_at: Time.now )
      expect( cache.in_progress? ).to be false
    end
  end

  describe "cached?" do
    it "is true if it has been recently cached" do
      endpoint = ApiEndpoint.make!( cache_hours: 48 )
      cache = ApiEndpointCache.make!( request_began_at: 1.day.ago,
        request_completed_at: 1.day.ago, api_endpoint: endpoint, success: true )
      expect( cache.cached? ).to be true
    end

    describe "throttled responses" do
      let( :endpoint ) { ApiEndpoint.make!( cache_hours: 720 ) }

      it "is true when throttled and the request completed within the retry window" do
        cache = ApiEndpointCache.make!( api_endpoint: endpoint, success: false,
          status_code: 429, request_began_at: 1.minute.ago,
          request_completed_at: 1.minute.ago )
        expect( cache.cached? ).to be true
      end

      it "is false when throttled and the request completed beyond the retry window" do
        cache = ApiEndpointCache.make!( api_endpoint: endpoint, success: false,
          status_code: 429,
          request_began_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago,
          request_completed_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
        expect( cache.cached? ).to be false
      end

      it "is false when throttled but the request never completed" do
        cache = ApiEndpointCache.make!( api_endpoint: endpoint, success: false,
          status_code: 429, request_began_at: 1.minute.ago,
          request_completed_at: nil )
        expect( cache.cached? ).to be false
      end
    end
  end

  describe "throttled?" do
    it "is true when the status code is 429" do
      cache = ApiEndpointCache.make!( status_code: 429 )
      expect( cache.throttled? ).to be true
    end

    it "is false for a normal successful response" do
      cache = ApiEndpointCache.make!( status_code: 200, response: "<parse><text>ok</text></parse>" )
      expect( cache.throttled? ).to be false
    end
  end

  describe "cache_throttled!" do
    let( :cache ) { ApiEndpointCache.make! }

    it "records a throttled response and stamps the endpoint" do
      cache.cache_throttled!( "Too many requests" )
      expect( cache.status_code ).to eq ApiEndpointCache::THROTTLED_STATUS_CODE
      expect( cache.success ).to be false
      expect( cache.response ).to eq "Too many requests"
      expect( cache.request_completed_at ).not_to be_nil
      expect( cache.api_endpoint.last_throttled_at ).to eq cache.request_completed_at
      expect( cache.api_endpoint.recently_throttled? ).to be true
    end

    it "does not require a body" do
      cache.cache_throttled!
      expect( cache.throttled? ).to be true
      expect( cache.response ).to be_nil
    end
  end

  describe "cache_response" do
    let( :cache ) { ApiEndpointCache.make! }

    def http_response( code:, body: )
      double( "Net::HTTPResponse", code: code.to_s, body: body )
    end

    it "stores a successful response" do
      cache.cache_response( http_response( code: 200, body: "<parse><text>ok</text></parse>" ) )
      expect( cache.status_code ).to eq 200
      expect( cache.success ).to be true
      expect( cache.throttled? ).to be false
      expect( cache.request_completed_at ).not_to be_nil
    end

    it "marks a 429 response as throttled and not a success" do
      cache.cache_response( http_response( code: 429, body: "Slow down!" ) )
      expect( cache.status_code ).to eq 429
      expect( cache.success ).to be false
      expect( cache.throttled? ).to be true
    end

    it "records a 429 response on the endpoint as last_throttled_at" do
      cache.cache_response( http_response( code: 429, body: "Slow down!" ) )
      expect( cache.api_endpoint.last_throttled_at ).to eq cache.request_completed_at
      expect( cache.api_endpoint.recently_throttled? ).to be true
    end

    it "translates a too-many-requests body to a throttled status code even with a 200 status" do
      cache.cache_response( http_response( code: 200,
        body: "You are making too many requests.\nPlease reduce your request rate." ) )
      expect( cache.status_code ).to eq ApiEndpointCache::THROTTLED_STATUS_CODE
      expect( cache.success ).to be false
      expect( cache.throttled? ).to be true
      expect( cache.api_endpoint.last_throttled_at ).not_to be_nil
    end

    it "does not record last_throttled_at on the endpoint for a successful response" do
      cache.cache_response( http_response( code: 200, body: "<parse><text>ok</text></parse>" ) )
      expect( cache.api_endpoint.last_throttled_at ).to be_nil
    end

    it "does not mark a blank response as a success" do
      cache.cache_response( http_response( code: 200, body: "" ) )
      expect( cache.success ).to be false
      expect( cache.throttled? ).to be false
    end
  end
end
