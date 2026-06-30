class ApiEndpointCache < ApplicationRecord
  THROTTLE_RETRY_MINUTES = 30
  THROTTLED_STATUS_CODE = 429
  # Shared by .throttled_response? (Ruby) and the .throttled scope (SQL) — keep in sync.
  THROTTLED_BODY_PHRASE = "too many requests".freeze

  belongs_to :api_endpoint

  scope :throttled, lambda {
    where( "status_code = ? OR response ILIKE ?", THROTTLED_STATUS_CODE, "%#{THROTTLED_BODY_PHRASE}%" )
  }

  def in_progress?
    !!( request_began_at && !request_completed_at )
  end

  def self.throttled_response?( status_code, body )
    return true if status_code.to_i == THROTTLED_STATUS_CODE
    return true if body.to_s.downcase.include?( THROTTLED_BODY_PHRASE )

    false
  end

  def throttled?
    self.class.throttled_response?( status_code, response )
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
