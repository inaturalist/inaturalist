class FlickrCache

  TIMEOUT = 10

  def self.fetch(flickraw, type, method, params={})
    # find or create the endpoint
    @api_endpoint = ApiEndpoint.find_or_create_by(title: "Flickr",
      documentation_url: "http://www.flickr.com/services/api/",
      base_url: "https://api.flickr.com/services/rest?", cache_hours: 720)
    # find or create the cache entry for this call
    api_endpoint_cache = ApiEndpointCache.find_or_create_by(api_endpoint: @api_endpoint,
      request_url: "flickr.#{ type }.#{ method }(#{ params.to_json })")
    # return the cached entry if it is valid
    api_response = if api_endpoint_cache.cached?
      # it may have cached nil if there was a problem
      if cached_response = api_endpoint_cache.response
        JSON.parse(api_endpoint_cache.response).map do |r|
          # map each hash to an object, as we would get from Flickraw
          OpenStruct.new(r)
        end
      end
    else
      response = nil
      begin
        # mark the start time of the fetch
        api_endpoint_cache.update_attributes(request_began_at: Time.now,
          request_completed_at: nil, success: nil, response: nil)
        # call the API via Flickraw
        Timeout::timeout(TIMEOUT) do
          response = flickraw.send(type).send(method, params)
        end
        # mark the end time and update the cache with the results
        api_endpoint_cache.update_attributes(
          request_completed_at: Time.now, success: true, response: response.to_json)
      rescue Timeout::Error
        raise Timeout::Error, "Flickr didn't respond within #{TIMEOUT} seconds."
      rescue FlickRaw::FailedResponse, EOFError, OpenSSL::SSL::SSLError => e
        Rails.logger.error "Failed Flickr API request: #{e}"
        Rails.logger.error e.backtrace.join("\n\t")
        api_endpoint_cache.update_attributes(request_completed_at: Time.now, success: false)
      end
      response
    end
  end
end