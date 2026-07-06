class FlickrCache

  TIMEOUT = 10
  EXTRAS = "date_upload,owner_name,url_sq,url_t,url_s,url_m,url_l,url_o,license"

  def self.api_endpoint
    ApiEndpoint.find_or_create_by(title: "Flickr",
      documentation_url: "http://www.flickr.com/services/api/",
      base_url: "https://api.flickr.com/services/rest?", cache_hours: 720)
  end

  # Record that Flickr throttled a request made outside of fetch, e.g. an
  # image download from Flickr's static hosts
  def self.throttled!
    api_endpoint.update( last_throttled_at: Time.now )
  end

  def self.fetch(flickr, type, method, params={})
    # find or create the endpoint
    endpoint = api_endpoint
    # find or create the cache entry for this call
    api_endpoint_cache = ApiEndpointCache.find_or_create_by(api_endpoint: endpoint,
      request_url: "flickr.#{ type }.#{ method }(#{ params.to_json })")
    # return the cached entry if it is valid
    if api_endpoint_cache.cached?
      # a throttled response is not a valid API response; treat it as a cache
      # hit that yields nothing rather than parsing the throttling message
      return if api_endpoint_cache.throttled?

      # it may have cached nil if there was a problem
      if cached_response = api_endpoint_cache.response
        json_to_flickr( cached_response )
      end
    else
      # Flickr throttles by key, so while it is throttling us, don't ask it
      # for anything that isn't already cached
      return if endpoint.recently_throttled?

      response = nil
      begin
        # mark the start time of the fetch
        api_endpoint_cache.update(request_began_at: Time.now,
          request_completed_at: nil, success: nil, response: nil, status_code: nil)
        # call the API via Flickr
        Timeout::timeout(TIMEOUT) do
          response = request( flickr, type, method, params )
        end
        # mark the end time and update the cache with the results
        api_endpoint_cache.update(
          request_completed_at: Time.now, success: true, response: response)
      rescue Timeout::Error
        raise Timeout::Error, "Flickr didn't respond within #{TIMEOUT} seconds."
      rescue Flickr::FailedResponse, Flickr::OAuthClient::FailedResponse,
        EOFError, OpenSSL::SSL::SSLError => e
        Rails.logger.error "Failed Flickr API request: #{e}"
        Rails.logger.error e.backtrace.join("\n\t")
        if throttled_error?( e )
          api_endpoint_cache.cache_throttled!( error_body( e ) )
        else
          api_endpoint_cache.update(request_completed_at: Time.now, success: false)
        end
      end
      response ? json_to_flickr( response ) : nil
    end
  end

  def self.throttled_error?( error )
    # Flickr::FailedResponse#code is a Flickr API error code, not an HTTP
    # status, so only the body/message is meaningful here
    ApiEndpointCache.throttled_response?( nil, error_body( error ) )
  end

  def self.error_body( error )
    return error.message unless error.is_a?( Flickr::OAuthClient::FailedResponse )

    # The gem's constructor parses the raw HTTP body into a hash of oauth
    # params and discards the string; reassemble the text so it can be matched
    error.instance_variable_get( :@response ).to_a.flatten.compact.join( "=" )
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