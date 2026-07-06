require "spec_helper"

describe ApiEndpoint do
  it { is_expected.to have_many :api_endpoint_caches }

  describe "recently_throttled?" do
    let( :endpoint ) { ApiEndpoint.make!( cache_hours: 720 ) }

    it "is true when a recent cache has a 429 status code" do
      ApiEndpointCache.make!( api_endpoint: endpoint, success: false, status_code: 429,
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( endpoint.recently_throttled? ).to be true
    end

    it "is true when a recent response had a too-many-requests body but a 200 status code" do
      cache = ApiEndpointCache.make!( api_endpoint: endpoint, request_began_at: 1.minute.ago )
      cache.cache_response(
        double( "Net::HTTPResponse", code: "200", body: "You are making too many requests." )
      )
      expect( endpoint.recently_throttled? ).to be true
    end

    it "is false when the only throttled cache completed beyond the retry window" do
      ApiEndpointCache.make!( api_endpoint: endpoint, success: false, status_code: 429,
        request_began_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago,
        request_completed_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago )
      expect( endpoint.recently_throttled? ).to be false
    end

    it "is false when there are no throttled caches" do
      ApiEndpointCache.make!( api_endpoint: endpoint, success: true, status_code: 200,
        response: "<parse><text>ok</text></parse>",
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( endpoint.recently_throttled? ).to be false
    end

    it "evaluates throttling in SQL without instantiating cache records" do
      ApiEndpointCache.make!( api_endpoint: endpoint, success: false, status_code: 429,
        request_began_at: 1.minute.ago, request_completed_at: 1.minute.ago )
      expect( ApiEndpointCache ).not_to receive( :instantiate )
      expect( endpoint.recently_throttled? ).to be true
    end
  end
end
