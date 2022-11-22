require "spec_helper"

describe ApiEndpointCache do
  it { is_expected.to belong_to :api_endpoint }

  describe "in_progress?" do
    it "is true if it is in progress" do
      cache = ApiEndpointCache.make!(request_began_at: Time.now,
        request_completed_at: nil)
      expect(cache.in_progress?).to be true
    end

    it "is false when it hasn't begun" do
      cache = ApiEndpointCache.make!(request_began_at: nil)
      expect(cache.in_progress?).to be false
    end

    it "is false if it has completed" do
      cache = ApiEndpointCache.make!(request_began_at: Time.now,
        request_completed_at: Time.now)
      expect(cache.in_progress?).to be false
    end
  end

  describe "cached?" do
    it "is true if it has been recently cached" do
      endpoint = ApiEndpoint.make!(cache_hours: 48)
      cache = ApiEndpointCache.make!(request_began_at: 1.day.ago,
        request_completed_at: 1.day.ago, api_endpoint: endpoint, success: true)
      expect(cache.cached?).to be true
    end
  end
end
