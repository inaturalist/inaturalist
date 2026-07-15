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
      expect( cache.success ).to be_falsey
      expect( cache.throttled? ).to be true
    end

    it "does not persist the throttled response body" do
      cache.cache_response( http_response( code: 429, body: "You are making too many requests." ) )
      expect( cache.response ).to be_blank
    end

    it "retains a previously cached successful response when throttled" do
      cache.cache_response( http_response( code: 200, body: "<parse><text>ok</text></parse>" ) )
      cache.cache_response( http_response( code: 429, body: "You are making too many requests." ) )
      expect( cache.throttled? ).to be true
      # the last real response/success survive the throttle so we can serve them
      expect( cache.success ).to be true
      expect( cache.response ).to eq "<parse><text>ok</text></parse>"
      expect( cache.usable_response? ).to be true
    end

    it "logs the throttled response to Logstasher" do
      expect( Logstasher ).to receive( :write_hash ).with(
        hash_including(
          subtype: "ApiEndpointThrottled",
          status_code: ApiEndpointCache::THROTTLED_STATUS_CODE,
          error_message: "You are making too many requests."
        )
      )
      cache.cache_response( http_response( code: 429, body: "You are making too many requests." ) )
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
      expect( cache.success ).to be_falsey
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

  describe "usable_response?" do
    it "is true for a successful response with a body" do
      cache = ApiEndpointCache.make!( success: true, response: "<parse><text>ok</text></parse>" )
      expect( cache.usable_response? ).to be true
    end

    it "is false when there is no cached response body" do
      cache = ApiEndpointCache.make!( success: true, response: nil )
      expect( cache.usable_response? ).to be false
    end

    it "is false when the last real fetch was not a success" do
      cache = ApiEndpointCache.make!( success: false, response: "whatever" )
      expect( cache.usable_response? ).to be false
    end
  end
end
