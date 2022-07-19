#encoding: utf-8
class GbifService

  attr_reader :timeout, :service_name

  SERVICE_VERSION = 1.0

  ENDPOINT = "http://api.gbif.org/v1/"

  def initialize(options = {})
    @service_name = "GBIF API"
    @timeout ||= options[:timeout] || 5
    @debug ||= options[:debug]
  end

  def request(method, params = {})
    uri = self.class.url_for_request(method, params)
    begin
      timed_out = Timeout::timeout(@timeout) do
        puts "DEBUG: requesting #{uri}" if @debug
        response = Net::HTTP.get_response(uri)
        puts response.body if @debug
        if response.code == "200" && json = JSON.parse(response.body)
          return json
        end
      end
    rescue Timeout::Error
      raise Timeout::Error, "#{@service_name} didn't respond within #{@timeout} seconds."
    end
  end

  def self.species_match(options = {})
    @@service ||= new(options)
    @@service.request("species/match", options[:params])
  end

  def self.url_for_request(method, params = {})
    url = ENDPOINT + method + "?" + URI.encode_www_form( params )
    URI.parse(url)
  end

end
