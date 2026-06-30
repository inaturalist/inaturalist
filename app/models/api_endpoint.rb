class ApiEndpoint < ApplicationRecord
  has_many :api_endpoint_caches

  def recently_throttled?
    api_endpoint_caches.
      where( "request_completed_at > ?", ApiEndpointCache::THROTTLE_RETRY_MINUTES.minutes.ago ).
      throttled.
      exists?
  end

  def to_s
    "<ApiEndpoint #{id} #{base_url}>"
  end
end
