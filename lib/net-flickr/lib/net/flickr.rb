#--
# Copyright (c) 2007-2008 Ryan Grove <ryan@wonko.com>
# Copyright (c) 2008 Nate Agrin <n8@n8agrin.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#   * Neither the name of this project nor the names of its contributors may be
#     used to endorse or promote products derived from this software without
#     specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++

# Append this file's directory to the include path if it's not there already.
$:.unshift(File.dirname(__FILE__))
$:.uniq!

# stdlib includes
require 'digest/md5'
require 'net/http'
require 'uri'
require 'singleton'

# RubyGems includes
require 'rubygems'
require 'hpricot'

# Net::Flickr includes
require 'flickr/auth'
require 'flickr/contacts'
require 'flickr/errors'
require 'flickr/geo'
require 'flickr/people'
require 'flickr/person'
require 'flickr/photo'
require 'flickr/photos'
require 'flickr/tag'

# Net::Flickr List classes
require 'flickr/list' # must come first
require 'flickr/contactlist'
require 'flickr/photolist'

module Net

  # = Net::Flickr
  # 
  # This library implements Flickr's REST API. Its usage should be pretty
  # straightforward. See below for examples.
  # 
  # Author::    Ryan Grove (mailto:ryan@wonko.com)
  # Author::    Nate Agrin (mailto:n8@n8agrin.com) 
  # Version::   0.0.1
  # Copyright:: Copyright (c) 2007-2008 Ryan Grove. All rights reserved.
  # Copyright:: Copyright (c) 2008 Nate Agrin. All rights reserved.
  # License::   New BSD License (http://opensource.org/licenses/bsd-license.php)
  # Website::   http://code.google.com/p/net-flickr/
  # 
  # == APIs not yet implemented
  # 
  # * activity
  # * blogs
  # * contacts
  # * favorites
  # * groups
  # * groups.pools
  # * interestingness
  # * photos.comments
  # * photos.geo
  # * photos.licenses
  # * photos.notes
  # * photos.transform
  # * photos.upload
  # * photosets
  # * photosets.comments
  # * reflection
  # * tags
  # * test
  # * urls
  # 
  
  # Flickr is a singleton, so that you can use it in Rails and avoid
  # recursion issues when converting to something like JSON
  class Flickr
    include Singleton
    
    AUTH_URL      = 'http://flickr.com/services/auth/'.freeze
    REST_ENDPOINT = 'http://api.flickr.com/services/rest/'.freeze
    VERSION       = '0.1.0'.freeze

    attr_accessor :timeout, :api_key, :api_secret, :response
    
    # Creates a new Net::Flickr object that will use the specified _api_key_ and
    # _api_secret_ to connect to Flickr. If you don't already have a Flickr API
    # key, you can get one at http://flickr.com/services/api/keys.
    # 
    # If you don't provide an _api_secret_, you won't be able to make API calls
    # requiring authentication.
    def self.authorize(api_key, api_secret = nil)
      instance = instance()
      instance.api_key    = api_key
      instance.api_secret = api_secret
      instance
    end
    
    # calls to the inner classes
    def auth
      @auth ||= load_class(:Auth)
    end
    
    def contacts
      @contacts ||= load_class(:Contacts)
    end
    
    def people
      @people ||= load_class(:People)
    end
    
    def photos
      @photos ||= load_class(:Photos)
    end
    
    def photosets
      @photosets ||= load_class(:Photosets)
    end
    
    # Calls the specified Flickr REST API _method_ with the supplied arguments
    # and returns a Flickr REST response in XML format. If an API secret is set,
    # the request will be properly signed.
    def request(method, args = {})
      #clean the incoming parameter keys, make sure everything is uniq and a string
      params = {}
      args.each_key{ |key| params[key.to_s] = args[key].to_s }
      params.merge!({'method' => method, 'api_key' => @api_key})
      
      # PENDING
      # allow for a json object to be returned
      # params.merge({'format' => @format.to_s}) if @format == :json

      url     = URI.parse(REST_ENDPOINT)
      http    = Net::HTTP.new(url.host, url.port)
      request = sign_request(Net::HTTP::Post.new(url.path), params)
      
      http.start do |http|
        if block_given?
          http.request(request) { |response| yield response }
        else
          response = http.request(request)
        
          # Raise a Net::HTTP error if the HTTP request failed.
          unless response.is_a?(Net::HTTPSuccess) || 
              response.is_a?(Net::HTTPRedirection)
            response.error!
          end
          
          # Return the parsed response.
          return parse_response(response.body)
        end
      end
    end
    
    # Signs a Flickr URL with the API secret.
    # This is only called in flickr.auth.getFrob, flickr.auth.url_webapp,
    # flickr.auth.url_desktop
    def sign_url(url)
      # return url if @api_secret.nil?
      if @api_secret.nil?
        raise AuthorizationError, 'An API secret key is required to sign a url.'      
      end

      uri = URI.parse(url)

      params = uri.query.split('&')
      params << 'api_sig=' + Digest::MD5.hexdigest(@api_secret +
          params.sort.join('').gsub('=', ''))

      uri.query = params.join('&')

      return uri.to_s
    end
    
    private
    # the constructor is private, because it's a singleton
    def initialize
      @response = nil
      super
    end
    
    # Signs a Flickr API request with the API secret if set.
    def sign_request(request, params)
      # If the secret isn't set, we can't sign anything.
      if @api_secret.nil?
        request.set_form_data(params)
        return request
      end
      
      # Add auth_token to the param list if we're already authenticated.
      params['auth_token'] = auth.token unless auth.token.nil?
      
      # Build a sorted, concatenated parameter list as described at
      # http://flickr.com/services/api/auth.spec.html
      paramlist = ''
      params.keys.sort.each do |key|
        params[key].gsub!(' ', '+')
        paramlist << key << URI.escape(params[key])
      end

      # Sign the request with a hash of the secret key and the concatenated
      # parameter list.
      params['api_sig'] = Digest::MD5.hexdigest(@api_secret + paramlist)
##      
      p params
      
      request.set_form_data(params)
      
      return request      
    end
    
    # Parses the specified Flickr REST response. If the response indicates a
    # successful request, the response block will be returned as an Hpricot
    # element. Otherwise, an error will be raised.
    def parse_response(response_xml)
      begin
        xml = Hpricot::XML(response_xml)
      rescue => e
        raise InvalidResponse, 'Invalid Flickr API response'
      end
      
      unless @response = xml.at('/rsp')
        raise InvalidResponse, 'Invalid Flickr API response'
      end
      
      if @response['stat'] == 'ok'
        return @response
      elsif @response['stat'] == 'fail'
        raise APIError, @response.at('/err')['msg']
      else
        raise InvalidResponse, 'Invalid Flickr API response'
      end
    end

    # We use const_defined? because each sub library should be loaded by the
    # require statements at the top of this file. This keeps things simple,
    # at least for now.
    def load_class(klass)
      unless Net::Flickr.const_defined?(klass)
        raise LoadError, "Net::Flickr::#{klass.to_s} not found."
      end
      Net::Flickr.const_get(klass).new
    end
  end
end