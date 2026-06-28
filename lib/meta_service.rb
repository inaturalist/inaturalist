# frozen_string_literal: true

#
# MetaService is a generalized wrapper for ReST web services that use URLs
# like this:
#
#   http://provider.com/endpoint?method_param=method_name&other_param=other_value
#
# On the verge of copying code for a third of these kinds of wrappers, I
# figured the pattern was common enough to merit a little bit of
# consilidation.
#
# MetaService assumes an XML response, and returns Hpricot objects.
#

require "net/http"
require "uri"
require "timeout"

require "rubygems"
require "nokogiri"

class MetaService
  SERVICE_VERSION = 1

  def initialize( options = {} )
    @service_name = "Web Service"
    @timeout ||= 5
    @method_param ||= "function"
    @default_params = {}
    @debug = options[:debug]
  end

  attr_reader :timeout, :method_param, :service_name, :api_endpoint

  #
  # Sends a request to a service function, and returns an Hpricot object of
  # the xml response.
  #
  # TODO: handle bad responses!
  #
  def request( method, args = {} )
    params      = args.merge( { @method_param => method } )
    params      = params.merge( @default_params )
    endpoint    = api_endpoint ? api_endpoint.base_url : @endpoint
    url         = endpoint + URI.encode_www_form( params.reject {| k, _v | k == :force_update } )
    request_uri = URI.parse( url )
    begin
      MetaService.fetch_request_uri( args.merge(
        request_uri: request_uri,
        timeout: @timeout,
        api_endpoint: api_endpoint,
        user_agent: "#{Site.default.name}/#{self.class}/#{SERVICE_VERSION}"
      ) )
    rescue Timeout::Error
      raise Timeout::Error, "#{@service_name} didn't respond within #{@timeout} seconds."
    end
  end

  def method_missing( method, *args )
    # puts "DEBUG: You tried to call '#{method}'" # test
    params = *args
    params = params.first if params.is_a?( Array ) && params.size == 1
    unless params.nil? || ( params.is_a?( Hash ) && !params.empty? )
      raise "#{@service_name}##{method} arguments must be a Hash"
    end

    request( method, *args )
  end

  def self.fetch_request_uri( options = {} )
    return unless options[:request_uri]

    options[:timeout] ||= 5
    options[:user_agent] ||= Site.default.name
    if options[:api_endpoint]
      api_endpoint_cache = ApiEndpointCache.find_or_create_by(
        api_endpoint: options[:api_endpoint],
        request_url: options[:request_uri].to_s
      )
      return if api_endpoint_cache.in_progress?

      if api_endpoint_cache.cached? && !options[:force_update]
        # Serve a previously cached successful response if we have one — even
        # while we're inside a throttle back-off window. If we're throttled with
        # nothing good cached yet, this returns nil (treated as no response).
        return cached_response( api_endpoint_cache, options )
      end
    end
    response = nil
    # Remember when we last completed a real request so a throttle below can
    # restore it rather than advancing the cache_hours freshness window.
    previous_completed_at = api_endpoint_cache&.request_completed_at
    begin
      # Flip the in-progress guard, but keep any previously cached response/
      # success intact so a throttle (handled below) can't clobber it.
      api_endpoint_cache&.update(
        request_began_at: Time.now,
        request_completed_at: nil
      )
      Timeout.timeout( options[:timeout] ) do
        response = fetch_with_redirects( options )
      end
    rescue Timeout::Error
      api_endpoint_cache&.update(
        request_completed_at: Time.now,
        success: false
      )
      raise Timeout::Error
    end
    status_code = response.code.to_i
    # A throttling response (e.g. "You are making too many requests") may have a
    # non-blank body and even a 200 status, so detect it explicitly and never
    # treat it as a successful, cacheable response.
    throttled = status_code == 429 || response.body.to_s =~ /too many requests/i
    if throttled
      # Record the throttle so cached?/recently_throttled? backs off, but do NOT
      # overwrite a previously cached successful response with the throttle
      # message — we'd rather keep serving the good (if stale) data. Restore the
      # prior completion time (or stamp now if there was none) so we only clear
      # the in-progress guard without faking a fresh successful fetch.
      api_endpoint_cache&.update(
        request_completed_at: previous_completed_at || Time.now,
        status_code: status_code,
        throttled_at: Time.now
      )
      # Serve the prior cached success if we have one; otherwise no response.
      return cached_response( api_endpoint_cache, options )
    end
    api_endpoint_cache&.update(
      request_completed_at: Time.now,
      status_code: status_code,
      throttled_at: nil,
      success: !response.body.blank?,
      response: response.body
    )

    if options[:raw_response]
      return response.body
    end

    Nokogiri::XML( response.body )
  end

  # Returns the cached response in the requested form, or nil when there is no
  # usable cached response to serve.
  def self.cached_response( api_endpoint_cache, options )
    return unless api_endpoint_cache&.usable_response?

    return api_endpoint_cache.response if options[:raw_response]

    Nokogiri::XML( api_endpoint_cache.response )
  end
  private_class_method :cached_response

  def self.fetch_with_redirects( options, attempts = 3 )
    http = Net::HTTP.new( options[:request_uri].host, options[:request_uri].port )
    # using SSL if we have an https URL
    http.use_ssl = ( options[:request_uri].scheme == "https" )
    response = http.get(
      "#{options[:request_uri].path}?#{options[:request_uri].query}",
      "User-Agent" => options[:user_agent]
    )
    # following redirects if we haven't followed too many already
    if response.is_a?( Net::HTTPRedirection ) && attempts.positive?
      options[:request_uri] = URI.parse( response["location"] )
      return fetch_with_redirects( options, attempts - 1 )
    end
    response
  end
end
