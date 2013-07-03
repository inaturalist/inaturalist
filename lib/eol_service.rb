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
        response = Net::HTTP.start(request_uri.host) do |http|
          # puts "#{self.class.name} getting #{request_uri.host}#{request_uri.path}?#{request_uri.query}" if @debug
          # http.get("#{request_uri.path}?#{request_uri.query}", 'User-Agent' => "#{self.class}/#{SERVICE_VERSION}")
          puts "#{self.class.name} getting #{request_uri}" if @debug
          http.get(request_uri.to_s, 'User-Agent' => "#{self.class}/#{SERVICE_VERSION}")
        end
        Nokogiri::XML(response.body)
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
