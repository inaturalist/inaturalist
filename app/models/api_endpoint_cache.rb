class ApiEndpointCache < ApplicationRecord
  THROTTLE_RETRY_MINUTES = 30
  THROTTLED_STATUS_CODE = 429
  THROTTLED_BODY_PHRASE = "too many requests".freeze

  belongs_to :api_endpoint

  def in_progress?
    !!( request_began_at && !request_completed_at )
  end

  def self.throttled_response?( status_code, body )
    return true if status_code.to_i == THROTTLED_STATUS_CODE
    return true if body.to_s.downcase.include?( THROTTLED_BODY_PHRASE )

    false
  end

  def self.translated_status_code( status_code, body )
    throttled_response?( status_code, body ) ? THROTTLED_STATUS_CODE : status_code
  end

  def throttled?
    status_code.to_i == THROTTLED_STATUS_CODE
  end

  # True when we have a usable, successfully fetched response to serve. A
  # throttled row keeps the last real response/success intact (see
  # cache_response), so this stays true through a throttle back-off and lets us
  # serve the previously cached (if stale) response rather than nothing.
  def usable_response?
    !!( success? && response.present? )
  end

  # Record a completed HTTP response. A throttled response (which may arrive
  # with a 200 status and a "too many requests" body) is never treated as a
  # successful, cacheable response: we flag the row as throttled but deliberately
  # keep the last real response/success so callers can keep serving it while we
  # back off. The result is a row that is throttled? (status_code 429) yet may
  # still expose a prior success?/response ("currently throttled, last real fetch
  # succeeded"). The throttled body itself is not persisted; it is logged to
  # Logstasher for monitoring instead.
  def cache_response( response )
    status_code = self.class.translated_status_code( response.code.to_i, response.body )
    if status_code == THROTTLED_STATUS_CODE
      log_throttled_response( response )
      update( request_completed_at: Time.now, status_code: THROTTLED_STATUS_CODE )
      api_endpoint.update( last_throttled_at: request_completed_at )
    else
      update(
        request_completed_at: Time.now,
        status_code: status_code,
        success: !response.body.blank?,
        response: response.body
      )
    end
  end

  def cached?
    if throttled?
      return false if request_completed_at.nil?

      return ( ( Time.now - request_completed_at ) / 1.minute ) < THROTTLE_RETRY_MINUTES
    end
    return false unless success?
    # when cache_hours is nil, retain the cache forever
    return true if api_endpoint.cache_hours.nil?
    return false if request_completed_at.nil?

    # if the cached version is older than cache_hours, it has expired
    ( ( Time.now - request_completed_at ) / 1.hour ) < api_endpoint.cache_hours
  end

  private

  # Emit structured telemetry whenever we receive a fresh throttled response, so
  # we have visibility into how often and when remote APIs (e.g. Wikipedia) are
  # rate-limiting us. cache_response is only reached after an actual live fetch,
  # and a throttled row is not re-fetched within its retry window, so each log
  # corresponds to a newly-received throttle.
  def log_throttled_response( response )
    Logstasher.write_hash(
      "@timestamp": Time.now,
      subtype: "ApiEndpointThrottled",
      api_endpoint_id: api_endpoint_id,
      api_endpoint: api_endpoint.to_s,
      request_url: request_url,
      status_code: THROTTLED_STATUS_CODE,
      error_message: response.body.to_s[0...1000]
    )
  end
end
