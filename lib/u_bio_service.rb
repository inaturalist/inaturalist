#
# Wrapper class for the uBio ReSTish web service methods.  This class doesn't 
# do much more than pass along requests to uBio and return Nokogiri objects.  
# You have been warned.
#
# Note that uBio base64-encodes many of its names, so you will probably want
# to decode them when you get them back.  Maybe I'll write some custom methods
# that do this later...
#
class UBioService < MetaService
  def initialize(key_code, options = {})
    unless key_code
      throw UBioAuthorizationError, 
        "You must supply a valid keyCode to call uBio"
    end
    super(options)
    @service_name           = 'uBio'
    @endpoint               = 'http://www.ubio.org/webservices/service.php?'
    @lsid_endpoint          = 'http://www.ubio.org/authority/metadata.php?'
    @search_help_endpoint   = 'http://www.ubio.org/searchHelp.php?'
    @default_params = { :keyCode => key_code }
    @method_param = 'function'
    @timeout = 10 # uBio can be sloooooowww
    @debug = options[:debug] || false
  end
  
  #
  # Fetch an RDF response from uBio
  #
  # This isn't quite in keeping with the thin wrapper approach of this
  # library, but LSID resolution has a different endpoint than the regular web
  # services, and it seemed silly to make a completely different library for
  # uBio LSIDs.  An LSID library that resolved LSIDs to RDFs itself using some
  # third party resolver would be cool.  Maybe later.
  #
  # Params generally correspond to the parts of an LSID after the authority. 
  # See http://lsids.sourceforge.net for details.
  #
  # params:
  #   namespace  - namespace identification
  #   object     - object identification
  #   revision   - revision identification (optional)
  #
  # or you can just pass in an lsid
  #
  def lsid(params)
    if params.is_a? String
      lsid = params
    else
      lsid = "urn:lsid:ubio.org:%s:%s" % [params[:namespace], params[:object]]
      lsid += ":#{params[:revision]}" if params[:revision]
    end
    url = @lsid_endpoint + "lsid=" + lsid
    response = nil
    begin
      timed_out = Timeout::timeout(@timeout) do
        puts "uBio: #{url}" if @debug
        response  = Net::HTTP.get_response(URI.parse(uri))
      end
    rescue Timeout::Error
      raise Timeout::Error, "uBio didn't respond within #{timeout} seconds."
    rescue EOFError, Errno::ECONNRESET
      raise UBioConnectionError, "uBio did not respond."
    end
    Nokogiri::XML(response.body)
  end
  
  #
  # Wraps the method uBio uses for their autocomplete, which actually seems
  # more robust than their web service.  uBio uses this endpoint for their
  # autocomplete searches, so it just returns an HTML fragment containing a
  # link to a namebank entry.  This wrapper doesn't go any further than making
  # an Nokogiri object out of that response.
  #
  def search_help(q)
    url = @search_help_endpoint + URI.encode_www_form( { q: q } )
    response = nil
    begin
      timed_out = Timeout::timeout(@timeout) do
        puts "uBio: #{url}" if @debug
        response  = Net::HTTP.get_response(URI.parse(uri))
      end
    rescue Timeout::Error, Errno::ECONNRESET
      raise Timeout::Error, "uBio didn't respond within #{timeout} seconds."
    end
    Nokogiri::HTML(response.body)
  end
  
  #
  # Calls the searchHelp endpoint and returns an array of hashes in the form
  #   :namebankID => 111111, :name => ABCD, :link => http://www.ubio....
  #
  def simple_namebank_search(name)
    r = search_help(name)
    r.search('a').map do |a|
      { :namebankID => a['href'].split('=').last, 
        :name => a.inner_text, 
        :link => a['href'] }
    end
  end
end
class UBioAuthorizationError < StandardError; end
class UBioConnectionError < StandardError; end
