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

  describe "recently_throttled?" do
    it "is true when throttled within the retry window" do
      cache = ApiEndpointCache.make!( throttled_at: 1.minute.ago )
      expect( cache.recently_throttled? ).to be true
    end

    it "is false when throttled beyond the retry window" do
      cache = ApiEndpointCache.make!(
        throttled_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
      expect( cache.recently_throttled? ).to be false
    end

    it "is false when never throttled" do
      cache = ApiEndpointCache.make!( throttled_at: nil )
      expect( cache.recently_throttled? ).to be false
    end
  end

  describe "usable_response?" do
    it "is true for a successful response with a body" do
      cache = ApiEndpointCache.make!( success: true,
        response: "<parse><text>ok</text></parse>" )
      expect( cache.usable_response? ).to be true
    end

    it "is false when not successful" do
      cache = ApiEndpointCache.make!( success: false, response: "whatever" )
      expect( cache.usable_response? ).to be false
    end

    it "is false when the response is blank" do
      cache = ApiEndpointCache.make!( success: true, response: nil )
      expect( cache.usable_response? ).to be false
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

      it "is true while inside the throttle retry window" do
        cache = ApiEndpointCache.make!( api_endpoint: endpoint, success: false,
          throttled_at: 1.minute.ago )
        expect( cache.cached? ).to be true
      end

      it "is false once the throttle retry window has elapsed" do
        cache = ApiEndpointCache.make!( api_endpoint: endpoint, success: false,
          throttled_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
        expect( cache.cached? ).to be false
      end

      it "stays cached and serveable when a valid success is also throttled" do
        cache = ApiEndpointCache.make!( api_endpoint: endpoint, success: true,
          response: "<parse><text>ok</text></parse>",
          request_completed_at: 1.day.ago, throttled_at: 1.minute.ago )
        expect( cache.cached? ).to be true
        expect( cache.usable_response? ).to be true
      end
    end
  end
end
