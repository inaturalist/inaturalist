#encoding: utf-8
class EolService
  attr_reader :timeout, :service_name
  
  SERVICE_VERSION = 1.0
  
  def initialize(options = {})
    @service_name = 'EOL Service'
    @timeout ||= options[:timeout] || 5
    @debug = options[:debug]
  end

  def request(method, *args)
    request_uri = get_uri(method, *args)
    begin
      timed_out = Timeout::timeout(@timeout) do
        Rails.logger.debug "[DEBUG] #{self.class.name} getting #{request_uri}"
        Nokogiri::XML(open(request_uri))
      end
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
    uri = "http://eol.org/api/#{method}/#{SERVICE_VERSION}"
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
end
