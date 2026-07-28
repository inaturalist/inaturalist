class ApiEndpointCache < ApplicationRecord
  THROTTLE_RETRY_MINUTES = 90
  THROTTLED_STATUS_CODE = 429
  THROTTLED_BODY_PHRASE = "too many requests".freeze
  NOT_FOUND_STATUS_CODE = 404
  # MediaWiki reports a missing page for action=parse as a 200 with an <error> body
  NOT_FOUND_ERROR_CODES = %w(missingtitle invalidtitle).freeze

  belongs_to :api_endpoint

  def in_progress?
    !!( request_began_at && !request_completed_at )
  end

  def self.throttled_response?( status_code, body )
    return true if status_code.to_i == THROTTLED_STATUS_CODE
    return true if body.to_s.downcase.include?( THROTTLED_BODY_PHRASE )

    false
  end

  # Whether the response says the requested resource does not exist. MediaWiki
  # answers action=parse for an absent page with a 200 and an <error> body
  # rather than a 404, so the body has to be inspected. Note that action=query
  # reports a missing page as <page missing="">, with no <error> node, and is
  # deliberately not matched here.
  def self.not_found_response?( status_code, body )
    return true if status_code.to_i == NOT_FOUND_STATUS_CODE
    return false unless body.to_s.include?( "<error" )

    NOT_FOUND_ERROR_CODES.any? {| code | body.to_s.include?( "code=\"#{code}\"" ) }
  end

  def self.translated_status_code( status_code, body )
    return THROTTLED_STATUS_CODE if throttled_response?( status_code, body )
    return NOT_FOUND_STATUS_CODE if not_found_response?( status_code, body )

    status_code
  end

  def throttled?
    status_code.to_i == THROTTLED_STATUS_CODE
  end

  def not_found?
    status_code.to_i == NOT_FOUND_STATUS_CODE
  end

  # Record a completed HTTP response, translating throttled responses (which
  # may arrive with a 200 status and a "too many requests" body) to a 429
  # status code so they are never treated as successful, and missing-resource
  # responses (which MediaWiki delivers as a 200 with an <error> body) to a
  # 404. Neither is a success, but a 404 is a definitive answer, so it is
  # cached for the endpoint's full cache_hours like a successful response.
  # Throttled and missing bodies are still stored for monitoring/inspection.
  def cache_response( response )
    status_code = self.class.translated_status_code( response.code.to_i, response.body )
    update(
      request_completed_at: Time.now,
      status_code: status_code,
      success: ![THROTTLED_STATUS_CODE, NOT_FOUND_STATUS_CODE].include?( status_code ) &&
        !response.body.blank?,
      response: response.body
    )
    api_endpoint.update( last_throttled_at: request_completed_at ) if throttled?
  end

  def cached?
    if throttled?
      return false if request_completed_at.nil?

      return ( ( Time.now - request_completed_at ) / 1.minute ) < THROTTLE_RETRY_MINUTES
    end
    return false unless success? || not_found?
    # when cache_hours is nil, retain the cache forever
    return true if api_endpoint.cache_hours.nil?
    return false if request_completed_at.nil?

    # if the cached version is older than cache_hours, it has expired
    ( ( Time.now - request_completed_at ) / 1.hour ) < api_endpoint.cache_hours
  end
end
