require "spec_helper"

describe ApiEndpoint do
  it { is_expected.to have_many :api_endpoint_caches }

  describe "recently_throttled?" do
    let( :endpoint ) { ApiEndpoint.make!( cache_hours: 720 ) }

    it "is true when the endpoint was throttled within the retry window" do
      endpoint.update( last_throttled_at: 1.minute.ago )
      expect( endpoint.recently_throttled? ).to be true
    end

    it "is false when the endpoint was last throttled beyond the retry window" do
      endpoint.update(
        last_throttled_at: ( ApiEndpointCache::THROTTLE_RETRY_MINUTES + 1 ).minutes.ago
      )
      expect( endpoint.recently_throttled? ).to be false
    end

    it "is false when the endpoint has never been throttled" do
      expect( endpoint.recently_throttled? ).to be false
    end
  end
end
