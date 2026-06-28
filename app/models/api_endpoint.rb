class ApiEndpoint < ApplicationRecord

  has_many :api_endpoint_caches

  # True if any request to this endpoint was throttled within the retry window.
  # throttled_at is stamped whenever a fetch is throttled (a 429 status or a
  # "too many requests" body), independently of the cached response, so this is
  # a simple existence check.
  def recently_throttled?
    api_endpoint_caches.
      where( "throttled_at > ?", ApiEndpointCache::THROTTLE_RETRY_MINUTES.minutes.ago ).
      exists?
  end

  def to_s
    "<ApiEndpoint #{id} #{base_url}>"
  end

end
