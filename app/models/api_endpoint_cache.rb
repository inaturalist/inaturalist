class ApiEndpointCache < ApplicationRecord

  # How long to wait before re-attempting a request that was throttled. We
  # deliberately retry throttled requests much sooner than api_endpoint.cache_hours
  # (which can be as long as 30 days) since throttling is transient.
  THROTTLE_RETRY_MINUTES = 30

  belongs_to :api_endpoint

  def in_progress?
    !! (request_began_at && ! request_completed_at)
  end

  # True if the most recent request was throttled and we are still within the
  # back-off window. This is tracked separately from the cached response body
  # (via throttled_at) so a throttle never clobbers a previously cached success.
  def recently_throttled?
    return false if throttled_at.nil?

    ((Time.now - throttled_at) / 1.minute) < THROTTLE_RETRY_MINUTES
  end

  # True if we have a usable, successfully fetched response to serve.
  def usable_response?
    !! (success? && response.present?)
  end

  def cached?
    # While we're inside the throttle back-off window, don't re-query the API.
    # We serve whatever we already have (a previously cached success, if any)
    # rather than hammering an endpoint that just told us to slow down.
    return true if recently_throttled?
    return false unless success?
    # when cache_hours is nil, retain the cache forever
    return true if api_endpoint.cache_hours.nil?
    return false if request_completed_at.nil?
    # if the cached version is older than cache_hours, it has expired
    ((Time.now - request_completed_at) / 1.hour) < api_endpoint.cache_hours
  end

end
