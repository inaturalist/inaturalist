class ApiEndpointCache < ApplicationRecord

  belongs_to :api_endpoint

  def in_progress?
    !! (request_began_at && ! request_completed_at)
  end

  def cached?
    return false unless success?
    # when cache_hours is nil, retain the cache forever
    return true if api_endpoint.cache_hours.nil?
    return false if request_completed_at.nil?
    # if the cached version is older than cache_hours, it has expired
    ((Time.now - request_completed_at) / 1.hour) < api_endpoint.cache_hours
  end

end
