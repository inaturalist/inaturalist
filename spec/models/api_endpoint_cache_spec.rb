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

    it "is true when the response body indicates too many requests" do
      cache = ApiEndpointCache.make!( status_code: 200,
        response: "You are making too many requests.\nPlease reduce your request rate." )
      expect( cache.throttled? ).to be true
    end

    it "is false for a normal successful response" do
      cache = ApiEndpointCache.make!( status_code: 200, response: "<parse><text>ok</text></parse>" )
      expect( cache.throttled? ).to be false
    end
  end
end
