class ApiEndpoint < ApplicationRecord

  has_many :api_endpoint_caches

  # True if any request to this endpoint was throttled within the retry window.
  # We load recent caches and check throttled? in Ruby (rather than a SQL
  # status_code filter) so this catches both a 429 status and a
  # "too many requests" response body.
  def recently_throttled?
    api_endpoint_caches.
      where( "request_completed_at > ?", ApiEndpointCache::THROTTLE_RETRY_MINUTES.minutes.ago ).
      any?( &:throttled? )
  end

  def to_s
    "<ApiEndpoint #{id} #{base_url}>"
  end

end
