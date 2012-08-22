#
# Wrapper class for the NZOR ReSTish web service methods.  This class doesn't 
# do much more than pass along requests to NZOR and return Nokogiri objects.  
# You have been warned.
#
class NewZealandOrganismsRegister
  ENDPOINT = 'http://data.nzor.org.nz/'.freeze
  NAME_SEARCH_ENDPOINT = 'http://data.nzor.org.nz/names/search'.freeze

  attr_reader :timeout

  def initialize(timeout=5)
    @timeout = timeout
  end
  #
  # Sends a request to a NZOR function, and returns an Nokogiri object of the 
  # xml response.  There's really only the search method right now.
  #
  # TODO: handle bad responses!
  #
  def request(method, args = {})
    params = args
    url    = NAME_SEARCH_ENDPOINT + "?format=xml&" + 
             params.map {|k,v| "#{k}=#{v}"}.join('&')
    uri    = URI.encode(url.gsub("'", '*'))
    response = nil
    begin
      timed_out = Timeout::timeout(@timeout) do
        puts "DEBUG: requesting " + uri # test
        response  = Net::HTTP.get_response(URI.parse(uri))
        puts response.body
      end
    rescue Timeout::Error
      raise Timeout::Error, 
            "NZOR didn't respond within #{timeout} seconds."
    end
    Nokogiri::XML(response.body)
  end

  def method_missing(method, *args)
    params = *args
    unless params.is_a? Hash and not params.empty?
      raise "NZOR arguments must be a Hash"
    end
    request(method, *args)
  end
end
