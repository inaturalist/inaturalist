class ApiEndpointCache < ApplicationRecord
  THROTTLE_RETRY_MINUTES = 30

  belongs_to :api_endpoint

  def in_progress?
    !!( request_began_at && !request_completed_at )
  end

  def self.throttled_response?( status_code, body )
    return true if status_code.to_i == 429
    return true if body.to_s =~ /too many requests/i

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
