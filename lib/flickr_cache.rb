class FlickrCache

  TIMEOUT = 10
  EXTRAS = "date_upload,owner_name,url_sq,url_t,url_s,url_m,url_l,url_o,license"

  def self.fetch(flickr, type, method, params={})
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
        # JSON.parse(api_endpoint_cache.response).map do |r|
        #   # map each hash to an object, as we would get from Flickr
        #   OpenStruct.new(r)
        # end
        json_to_flickr( api_endpoint_cache.response )
      end
    else
      response = nil
      begin
        # mark the start time of the fetch
        api_endpoint_cache.update(request_began_at: Time.now,
          request_completed_at: nil, success: nil, response: nil)
        # call the API via Flickr
        Timeout::timeout(TIMEOUT) do
          response = request( flickr, type, method, params )
        end
        # mark the end time and update the cache with the results
        api_endpoint_cache.update(
          request_completed_at: Time.now, success: true, response: response)
      rescue Timeout::Error
        raise Timeout::Error, "Flickr didn't respond within #{TIMEOUT} seconds."
      rescue Flickr::FailedResponse, EOFError, OpenSSL::SSL::SSLError => e
        Rails.logger.error "Failed Flickr API request: #{e}"
        Rails.logger.error e.backtrace.join("\n\t")
        api_endpoint_cache.update(request_completed_at: Time.now, success: false)
      end
      response ? json_to_flickr( response ) : nil
    end
  end

  def self.request( flickr, type, method, params )
    flickr.send( type ).send( method, params ).to_json
  end

  def self.json_to_flickr( json )
    JSON.parse( json ).map do |r|
      # map each hash to an object, as we would get from Flickr
      to_recursive_ostruct( r )
    end 
  end

  # https://stackoverflow.com/questions/42519557/convert-hash-to-openstruct-recursively
  def self.to_recursive_ostruct( hash )
    new_hash = hash.each_with_object({}) do |(key, val), memo|
      memo[key] = val.is_a?(Hash) ? to_recursive_ostruct(val) : val
    end
    OpenStruct.new( new_hash )
  end
end