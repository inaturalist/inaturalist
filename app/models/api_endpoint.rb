class ApiEndpoint < ApplicationRecord
  has_many :api_endpoint_caches

  def recently_throttled?
    last_throttled_at.present? &&
      last_throttled_at > ApiEndpointCache::THROTTLE_RETRY_MINUTES.minutes.ago
  end

  def to_s
    "<ApiEndpoint #{id} #{base_url}>"
  end
end
