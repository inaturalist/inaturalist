#--
# Copyright (c) 2007-2008 Ryan Grove <ryan@wonko.com>
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

module Net; class Flickr

  # Implements the Flickr authentication API. Please see
  # http://flickr.com/services/api/auth.spec.html for details on how to use this
  # API in your application.
  # 
  # Don't instantiate this class yourself. Instead, create an instance of the
  # +Flickr+ class and then user <tt>Flickr.auth</tt> to access this class,
  # like so:
  # 
  #   require 'net/flickr'
  #   
  #   flickr = Net::Flickr.new('524266cbd9d3c2xa2679fee8b337fip2',
  #       '835hae5d6j0sd47a')
  #   
  #   puts flickr.auth.url_desktop
  # 
  class Auth
    PERM_NONE   = :none
    PERM_READ   = :read
    PERM_WRITE  = :write
    PERM_DELETE = :delete
  
    attr_reader :frob, :perms, :user_id, :user_name, :user_fullname
    
    # allows the token to be set if its already been fetched and stored
    # in a database or flat file
    attr_accessor :token
    
    def initialize
      @frob          = nil
      @perms         = PERM_NONE
      @token         = nil
      @user_id       = nil
      @user_name     = nil
      @user_fullname = nil
    end
    
    #--
    # Public Instance Methods
    #++
    
    # Updates this Auth object with the credentials attached to the specified
    # authentication _token_. If the _token_ is not valid, an APIError will be
    # raised.
    def check_token(token = @token)
      update_auth(Net::Flickr.instance().request('flickr.auth.checkToken',
          'auth_token' => token))
      return true
    end
    
    # Gets the full authentication token for the specified _mini_token_.
    def full_token(mini_token)
      update_auth(Net::Flickr.instance().request('flickr.auth.getFullToken',
          'mini_token' => mini_token))
      return @token
    end
    
    # Gets a frob to be used during authentication.
    def get_frob
      response = Net::Flickr.instance().request('flickr.auth.getFrob').at('frob')
      return @frob = response.inner_text
    end
  
    # Updates this Auth object with the credentials for the specified _frob_ and
    # returns an auth token. If the _frob_ is not valid, an APIError will be
    # raised.
    def get_token(frob = @frob)
      update_auth(Net::Flickr.instance().request('flickr.auth.getToken', 'frob' => frob))
      return @token
    end
    
    # Gets a signed URL that can by used by a desktop application to show the
    # user a Flickr authentication screen. Once the user has visited this URL
    # and authorized your application, you can call get_token to authenticate.
    def url_desktop(perms = :read)
      get_frob if @frob.nil?
      url = Flickr::AUTH_URL +
          "?api_key=#{Net::Flickr.instance().api_key}&perms=#{perms}&frob=#{@frob}"
      
      return Net::Flickr.instance().sign_url(url)
    end
    
    # Gets a signed URL that can be used by a web application to show the user a
    # Flickr authentication screen. Once the user has visited this URL and
    # authorized your application, you can call get_token with the frob provided
    # by Flickr to authenticate.
    def url_webapp(perms = :read)
      return Net::Flickr.instance().sign_url(Flickr::AUTH_URL +
          "?api_key=#{Net::Flickr.instance().api_key}&perms=#{perms}")
    end
    
    #--
    # Private Instance Methods
    #++
    
    private
    
    # Updates this Auth object with the credentials in the specified XML
    # _response_.
    def update_auth(response)
      auth = response.at('auth')
      user = auth.at('user')
      
      @perms         = auth.at('perms').inner_text.to_sym
      @token         = auth.at('token').inner_text
      @user_id       = user['nsid']
      @user_name     = user['username']
      @user_fullname = user['fullname']
    end
  end

end; end
