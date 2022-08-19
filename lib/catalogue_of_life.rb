#
# Wrapper class for the CoL ReSTish web service methods.  This class doesn't 
# do much more than pass along requests to uBio and return Hpricot objects.  
# You have been warned.
#
class CatalogueOfLife
  ENDPOINT = 'http://www.catalogueoflife.org/annual-checklist/2012/webservice'.freeze

  attr_reader :timeout

  def initialize(timeout=5, options = {})
    @timeout = timeout
    @debug = options[:debug]
  end
  #
  # Sends a request to a CoL function, and returns an Hpricot object of the 
  # xml response.  There's really only the search method right now.
  #
  # TODO: handle bad responses!
  #
  def request(method, args = {})
    uri = self.class.url_for_request(method, args)
    response = nil
    begin
      timed_out = Timeout::timeout(@timeout) do
        puts "DEBUG: requesting #{uri}" if @debug
        response  = Net::HTTP.get_response(uri)
        puts response.body if @debug
      end
    rescue Timeout::Error
      raise Timeout::Error, 
            "Catalogue of Life didn't respond within #{timeout} seconds."
    end
    Nokogiri::XML(response.body)
  end

  def method_missing(method, *args)
    params = args.try(:first)
    unless params.is_a?(Hash) && !params.blank?
      raise "Catalogue of Life arguments must be a Hash"
    end
    request(method, *args)
  end

  def self.url_for_request(method, args = {})
    params = args
    url = ENDPOINT + "?" + URI.encode_www_form( params )
    URI.parse( url )
  end
end
