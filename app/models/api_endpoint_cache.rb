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

  # Record a completed HTTP response, translating throttled responses (which
  # may arrive with a 200 status and a "too many requests" body) to a 429
  # status code so they are never treated as successful. The throttled body is
  # still stored for monitoring/inspection.
  def cache_response( response )
    status_code = self.class.translated_status_code( response.code.to_i, response.body )
    update(
      request_completed_at: Time.now,
      status_code: status_code,
      success: status_code != THROTTLED_STATUS_CODE && !response.body.blank?,
      response: response.body
    )
    api_endpoint.update( last_throttled_at: request_completed_at ) if throttled?
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
end
