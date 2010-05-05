# encoding: ascii-8bit
# Copyright (c) 2006 Mael Clerambault <maelclerambault@yahoo.fr>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


require 'net/http'
require 'digest/md5'
require 'json'

FlickRawOptions = {} if not Object.const_defined? :FlickRawOptions # :nodoc:
FlickRawOptions['api_key'] ||= '7b124df89b638e545e3165293883ef62'
if ENV['http_proxy'] and not FlickRawOptions['proxy_host']
  proxy = URI.parse ENV['http_proxy']
  FlickRawOptions.update('proxy_host' => proxy.host, 'proxy_port' => proxy.port, 'proxy_user' => proxy.user, 'proxy_password' => proxy.password)
end

module FlickRaw
  VERSION='0.8.1'

  FLICKR_HOST='api.flickr.com'.freeze
  REST_PATH='/services/rest/?'.freeze
  UPLOAD_PATH='/services/upload/'.freeze
  REPLACE_PATH='/services/replace/'.freeze

  AUTH_PATH='http://flickr.com/services/auth/?'.freeze
  PHOTO_SOURCE_URL='http://farm%s.static.flickr.com/%s/%s_%s%s.%s'.freeze
  URL_PROFILE='http://www.flickr.com/people/'.freeze
  URL_PHOTOSTREAM='http://www.flickr.com/photos/'.freeze
  URL_SHORT="http://flic.kr/p/".freeze

  class Response
    def self.build(h, type) # :nodoc:
      if type =~ /s$/ and (a = h[$`]).is_a? Array
        ResponseList.new(h, type, a.collect {|e| Response.build(e, $`)})
      elsif h.keys == ["_content"]
        h["_content"]
      else
        Response.new(h, type)
      end
    end

    attr_reader :flickr_type
    def initialize(h, type) # :nodoc:
      @flickr_type, @h = type, {}
      methods = "class << self;"
      h.each {|k,v|
        @h[k] = case v
          when Hash  then Response.build(v, k)
          when Array then v.collect {|e| Response.build(e, k)}
          else v
        end
        methods << "def #{k}; @h['#{k}'] end;"
      }
      eval methods << "end"
    end
    def [](k); @h[k] end
    def to_s; @h["_content"] || super end
    def inspect; @h.inspect end
    def to_hash; @h end
  end

  class ResponseList < Response
    include Enumerable
    def initialize(h, t, a); super(h, t); @a = a end
    def [](k); k.is_a?(Fixnum) ? @a[k] : super(k) end
    def each; @a.each{|e| yield e} end
    def to_a; @a end
    def inspect; @a.inspect end
    def size; @a.size end
  end

  class FailedResponse < StandardError
    attr_reader :code
    alias :msg :message
    def initialize(msg, code, req)
      @code = code
      super("'#{req}' - #{msg}")
    end
  end

  class Request
    def initialize(flickr = nil) # :nodoc:
      @flickr = flickr

      self.class.flickr_objects.each {|name|
        klass = self.class.const_get name.capitalize
        instance_variable_set "@#{name}", klass.new(@flickr)
      }
    end

    def self.build_request(req) # :nodoc:
      method_nesting = req.split '.'
      raise "'#{@name}' : Method name mismatch" if method_nesting.shift != request_name.split('.').last

      if method_nesting.size > 1
        name = method_nesting.first
        class_name = name.capitalize
        if flickr_objects.include? name
          klass = const_get(class_name)
        else
          klass = Class.new Request
          const_set(class_name, klass)
          attr_reader name
          flickr_objects << name
        end

        klass.build_request method_nesting.join('.')
      else
        req = method_nesting.first
        define_method(req) { |*args|
          class_req = self.class.request_name
          @flickr.call class_req + '.' + req, *args
        }
        flickr_methods << req
      end
    end

    # List of the flickr subobjects of this object
    def self.flickr_objects; @flickr_objects ||= [] end

    # List of the flickr methods of this object
    def self.flickr_methods; @flickr_methods ||= [] end

    # Returns the prefix of the request corresponding to this class.
    def self.request_name; name.downcase.gsub(/::/, '.').sub(/[^\.]+\./, '') end
  end

  # Root class of the flickr api hierarchy.
  class Flickr < Request
    def self.build(methods); methods.each { |m| build_request m } end

    def initialize(token = FlickRawOptions['auth_token']) # :nodoc:
      Flickr.build(call('flickr.reflection.getMethods')) if Flickr.flickr_objects.empty?
      super self
      @token = token
    end

    # This is the central method. It does the actual request to the flickr server.
    #
    # Raises FailedResponse if the response status is _failed_.
    def call(req, args={})
      http_response = open_flickr do |http|
        request = Net::HTTP::Post.new(REST_PATH, 'User-Agent' => "Flickraw/#{VERSION}")
        request.set_form_data(build_args(args, req))
        http.request(request)
      end

      json = JSON.load(http_response.body.empty? ? "{}" : http_response.body)
      raise FailedResponse.new(json['message'], json['code'], req) if json.delete('stat') == 'fail'
      type, json = json.to_a.first if json.size == 1 and json.all? {|k,v| v.is_a? Hash}

      res = Response.build json, type
      @token = res.token if res.respond_to? :flickr_type and res.flickr_type == "auth"
      res
    end

    # Use this to upload the photo in _file_.
    #
    #  flickr.upload_photo '/path/to/the/photo', :title => 'Title', :description => 'This is the description'
    #
    # See http://www.flickr.com/services/api/upload.api.html for more information on the arguments.
    def upload_photo(file, args={}); upload_flickr(UPLOAD_PATH, file, args) end

    # Use this to replace the photo with :photo_id with the photo in _file_.
    #
    #  flickr.replace_photo '/path/to/the/photo', :photo_id => id
    #
    # See http://www.flickr.com/services/api/replace.api.html for more information on the arguments.
    def replace_photo(file, args={}); upload_flickr(REPLACE_PATH, file, args) end

    private
    def build_args(args={}, req = nil)
      full_args = {:api_key => FlickRaw.api_key, :format => 'json', :nojsoncallback => "1"}
      full_args[:method] = req if req
      full_args[:auth_token] = @token if @token
      args.each {|k, v|
        v = v.to_s.encode("utf-8").force_encoding("ascii-8bit") if RUBY_VERSION >= "1.9"
        full_args[k.to_sym] = v.to_s
      }
      full_args[:api_sig] = FlickRaw.api_sig(full_args) if FlickRaw.shared_secret
      full_args
    end

    def open_flickr
      Net::HTTP::Proxy(FlickRawOptions['proxy_host'], FlickRawOptions['proxy_port'], FlickRawOptions['proxy_user'], FlickRawOptions['proxy_password']).start(FLICKR_HOST) {|http|
        http.read_timeout = FlickRawOptions['timeout'] if FlickRawOptions['timeout']
        yield http
      }
    end

    def upload_flickr(method, file, args={})
      photo = File.open(file, 'rb') { |f| f.read }
      boundary = Digest::MD5.hexdigest(photo)

      header = {'Content-type' => "multipart/form-data, boundary=#{boundary} ", 'User-Agent' => "Flickraw/#{VERSION}"}
      query = ''

      file = file.to_s.encode("utf-8").force_encoding("ascii-8bit") if RUBY_VERSION >= "1.9"
      build_args(args).each { |a, v|
        query <<
          "--#{boundary}\r\n" <<
          "Content-Disposition: form-data; name=\"#{a}\"\r\n\r\n" <<
          "#{v}\r\n"
      }
      query <<
        "--#{boundary}\r\n" <<
        "Content-Disposition: form-data; name=\"photo\"; filename=\"#{file}\"\r\n" <<
        "Content-Transfer-Encoding: binary\r\n" <<
        "Content-Type: image/jpeg\r\n\r\n" <<
        photo <<
        "\r\n" <<
        "--#{boundary}--"

      http_response = open_flickr {|http| http.post(method, query, header) }
      xml = http_response.body
      if xml[/stat="(\w+)"/, 1] == 'fail'
        msg = xml[/msg="([^"]+)"/, 1]
        code = xml[/code="([^"]+)"/, 1]
        raise FailedResponse.new(msg, code, 'flickr.upload')
      end
      type = xml[/<(\w+)/, 1]
      h = {
        "secret" => xml[/secret="([^"]+)"/, 1],
        "originalsecret" => xml[/originalsecret="([^"]+)"/, 1],
        "_content" => xml[/>([^<]+)<\//, 1]
      }.delete_if {|k,v| v.nil? }
      Response.build(h, type)
    end
  end

  class << self
    # Your flickr API key, see http://www.flickr.com/services/api/keys for more information
    def api_key; FlickRawOptions['api_key'] end
    def api_key=(key); FlickRawOptions['api_key'] = key end

    # The shared secret of _api_key_, see http://www.flickr.com/services/api/keys for more information
    def shared_secret; FlickRawOptions['shared_secret'] end
    def shared_secret=(key); FlickRawOptions['shared_secret'] = key end

    # Returns the flickr auth URL.
    def auth_url(args={})
      full_args = {:api_key => api_key, :perms => 'read'}
      args.each {|k, v| full_args[k.to_sym] = v }
      full_args[:api_sig] = api_sig(full_args) if shared_secret

      AUTH_PATH + full_args.collect { |a, v| "#{a}=#{v}" }.join('&')
    end

    # Returns the signature of hsh. This is meant to be passed in the _api_sig_ parameter.
    def api_sig(hsh)
      Digest::MD5.hexdigest(FlickRaw.shared_secret + hsh.sort{|a, b| a[0].to_s <=> b[0].to_s }.flatten.join)
    end

    BASE58_ALPHABET="123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ".freeze
    def base58(id)
      id = id.to_i
      alphabet = BASE58_ALPHABET.split(//)
      base = alphabet.length
      begin
        id, m = id.divmod(base)
        r = alphabet[m] + (r || '')
      end while id > 0
      r
    end

    def url(r);   PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "",   "jpg"]   end
    def url_m(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_m", "jpg"] end
    def url_s(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_s", "jpg"] end
    def url_t(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_t", "jpg"] end
    def url_b(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.secret, "_b", "jpg"] end
    def url_o(r); PHOTO_SOURCE_URL % [r.farm, r.server, r.id, r.originalsecret, "_o", r.originalformat] end
    def url_profile(r); URL_PROFILE + (r.owner.respond_to?(:nsid) ? r.owner.nsid : r.owner) + "/" end
    def url_photopage(r); url_photostream(r) + r.id end
    def url_photosets(r); url_photostream(r) + "sets/" end
    def url_photoset(r); url_photosets(r) + r.id end
    def url_short(r); URL_SHORT + base58(r.id) end
    def url_photostream(r)
      URL_PHOTOSTREAM +
        if r.respond_to?(:pathalias) and r.pathalias
          r.pathalias
        elsif r.owner.respond_to?(:nsid)
          r.owner.nsid
        else
          r.owner
        end + "/"
    end
  end
end

# Use this to access the flickr API easily. You can type directly the flickr requests as they are described on the flickr website.
#  require 'flickraw'
#
#  recent_photos = flickr.photos.getRecent
#  puts recent_photos[0].title
def flickr; $flickraw ||= FlickRaw::Flickr.new end

# Load the methods if the option lazyload is not specified
flickr if not FlickRawOptions['lazyload']
