class ApiEndpointCache < ApplicationRecord

  # How long to wait before re-attempting a request that was throttled. We
  # deliberately retry throttled requests much sooner than api_endpoint.cache_hours
  # (which can be as long as 30 days) since throttling is transient.
  THROTTLE_RETRY_MINUTES = 30

  belongs_to :api_endpoint

  def in_progress?
    !! (request_began_at && ! request_completed_at)
  end

  # True if the remote API throttled the request. We can't rely on the status
  # code alone (it isn't always 429), so we also sniff the response body.
  def throttled?
    return true if status_code == 429
    return true if response.to_s =~ /too many requests/i

    false
  end

  def cached?
    if throttled?
      # Keep serving "no response" without re-fetching until the retry window
      # has elapsed, then allow a fresh attempt.
      return false if request_completed_at.nil?

      return ((Time.now - request_completed_at) / 1.minute) < THROTTLE_RETRY_MINUTES
    end
    return false unless success?
    # when cache_hours is nil, retain the cache forever
    return true if api_endpoint.cache_hours.nil?
    return false if request_completed_at.nil?
    # if the cached version is older than cache_hours, it has expired
    ((Time.now - request_completed_at) / 1.hour) < api_endpoint.cache_hours
  end

end
