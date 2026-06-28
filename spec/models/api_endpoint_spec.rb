require "spec_helper"

describe ApiEndpoint do
  it { is_expected.to have_many :api_endpoint_caches }

  describe "recently_throttled?" do
    let( :endpoint ) { ApiEndpoint.make!( cache_hours: 720 ) }

    it "is true when a recent cache was throttled within the retry window" do
      ApiEndpointCache.make!( api_endpoint: endpoint, success: false,
        throttled_at: 1.minute.ago )
      expect( endpoint.recently_throttled? ).to be true
    end

    it "is false when the only throttled cache is beyond the retry window" do
      ApiEndpointCache.make!( api_endpoint: endpoint, success: false,
        throttled_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
      expect( endpoint.recently_throttled? ).to be false
    end

    it "is false when there are no throttled caches" do
      ApiEndpointCache.make!( api_endpoint: endpoint, success: true, status_code: 200,
        response: "<parse><text>ok</text></parse>",
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( endpoint.recently_throttled? ).to be false
    end
  end
end
