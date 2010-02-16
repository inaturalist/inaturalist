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

require 'net/http'
require 'uri'
require 'timeout'

require 'rubygems'
require 'hpricot'


class MetaService
  attr_reader :timeout, :method_param, :service_name
  
  VERSION = 1
  
  def initialize
    @service_name = 'Web Service'
    @timeout ||= 5
    @method_param ||= 'function'
    @default_params = {}
  end

  #
  # Sends a request to a service function, and returns an Hpricot object of
  # the xml response.
  #
  # TODO: handle bad responses!
  #
  def request(method, args = {})
    # params = args.merge({@@method_param => method, 'keyCode' => @api_key})
    params      = args.merge({@method_param => method})
    params      = params.merge(@default_params)
    url         = @endpoint + params.map {|k,v| "#{k}=#{v}"}.join('&')
    uri         = URI.encode(url)
    request_uri = URI.parse(uri)
    response = nil
    begin
      timed_out = Timeout::timeout(@timeout) do
        response = Net::HTTP.start(request_uri.host) do |http|
          http.get("#{request_uri.path}?#{request_uri.query}", 
            'User-Agent' => "#{self.class}/#{VERSION}")
        end
      end
    rescue Timeout::Error
      raise Timeout::Error, "#{@service_name} didn't respond within #{@timeout} seconds."
    end
    Hpricot::XML(response.body)
  end

  def method_missing(method, *args)
    # puts "DEBUG: You tried to call '#{method}'" # test
    params = *args
    unless params.nil? || (params.is_a?(Hash) and not params.empty?)
      raise "#{@service_name}##{method} arguments must be a Hash"
    end
    request(method, *args)
  end
end
