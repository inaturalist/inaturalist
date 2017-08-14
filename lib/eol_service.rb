#encoding: utf-8
class EolService
  attr_reader :timeout, :service_name
  
  SERVICE_VERSION = 1.0
  
  def initialize(options = {})
    @service_name = 'EOL Service'
    @timeout ||= options[:timeout] || 5
    @debug = options[:debug]
  end

  def api_endpoint
    if @api_endpoint.blank? || @api_endpoint.new_record? 
      @api_endpoint = ApiEndpoint.find_or_create_by!(
        title: "EOL Service",
        documentation_url: "http://eol.org/api",
        base_url: "http://eol.org/api/",
        cache_hours: 720)
    end
    @api_endpoint
  end

  def request(method, *args)
    request_uri = get_uri(method, *args)
    Rails.logger.debug "[DEBUG] getting #{request_uri}, args: #{args.inspect}"
    begin
      MetaService.fetch_request_uri(request_uri: request_uri, timeout: @timeout,
        api_endpoint: api_endpoint,
        user_agent: "#{Site.default.name}/#{self.class}/#{SERVICE_VERSION}")
    rescue Timeout::Error
      raise Timeout::Error, "#{@service_name} didn't respond within #{@timeout} seconds."
    end
  end

  def method_missing(method, *args)
    request(method, *args) 
  end

  def page(id, params = {})
    request('pages', id, params)
  end

  def search(term, params = {})
    params = if term.is_a?(Hash)
      params.merge(term)
    else
      params.merge(:q => term)
    end
    request('search', params)
  end

  def get_uri(method, *args)
    arg = args.first unless args.first.is_a?(Hash)
    params = args.detect{|a| a.is_a?(Hash)} || {}
    uri = "#{ api_endpoint.base_url }#{ method }/#{ SERVICE_VERSION }"
    uri += "/#{arg}" if arg
    uri += ".xml"
    unless params.blank?
      uri += "?"
      uri += params.map {|k,v| "#{k}=#{v}"}.join('&') 
    end
    URI.parse(URI.encode(uri))
  end

  def self.method_missing(method, *args)
    @@service ||= new
    @@service.send(method, *args)
  end

  # This is a temporary workaround until EOL fixes their data objects API. 
  # See https://github.com/EOL/tramea/issues/137
  def data_objects(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    options[:images] = 1
    options[:sounds] = 1
    options[:text] = 1
    options[:details] = 1
    request('data_objects', *[args, options].flatten)
  end
end
