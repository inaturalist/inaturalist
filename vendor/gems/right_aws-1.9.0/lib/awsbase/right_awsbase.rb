#
# Copyright (c) 2007-2008 RightScale Inc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# Test
module RightAws
  require 'md5'
  require 'pp'
  
  class AwsUtils #:nodoc:
    @@digest = OpenSSL::Digest::Digest.new("sha1")
    def self.sign(aws_secret_access_key, auth_string)
      Base64.encode64(OpenSSL::HMAC.digest(@@digest, aws_secret_access_key, auth_string)).strip
    end

    # From Amazon's SQS Dev Guide, a brief description of how to escape:
    # "URL encode the computed signature and other query parameters as specified in 
    # RFC1738, section 2.2. In addition, because the + character is interpreted as a blank space 
    # by Sun Java classes that perform URL decoding, make sure to encode the + character 
    # although it is not required by RFC1738."
    # Avoid using CGI::escape to escape URIs. 
    # CGI::escape will escape characters in the protocol, host, and port
    # sections of the URI.  Only target chars in the query
    # string should be escaped.
    def self.URLencode(raw)
      e = URI.escape(raw)
      e.gsub(/\+/, "%2b")
    end
    
    def self.allow_only(allowed_keys, params)
      bogus_args = []
      params.keys.each {|p| bogus_args.push(p) unless allowed_keys.include?(p) }
      raise AwsError.new("The following arguments were given but are not legal for the function call #{caller_method}: #{bogus_args.inspect}") if bogus_args.length > 0
    end
    
    def self.mandatory_arguments(required_args, params)
      rargs = required_args.dup
      params.keys.each {|p| rargs.delete(p)}
      raise AwsError.new("The following mandatory arguments were not provided to #{caller_method}: #{rargs.inspect}") if rargs.length > 0
    end
    
    def self.caller_method
      caller[1]=~/`(.*?)'/
      $1
    end

  end

  class AwsBenchmarkingBlock #:nodoc:
    attr_accessor :xml, :service
    def initialize
      # Benchmark::Tms instance for service (Ec2, S3, or SQS) access benchmarking.
      @service = Benchmark::Tms.new()
      # Benchmark::Tms instance for XML parsing benchmarking.
      @xml = Benchmark::Tms.new()
    end
  end

  class AwsNoChange < RuntimeError
  end
  
  class RightAwsBase

    # Amazon HTTP Error handling

    # Text, if found in an error message returned by AWS, indicates that this may be a transient
    # error. Transient errors are automatically retried with exponential back-off.
    AMAZON_PROBLEMS = [ 'internal service error', 
                      'is currently unavailable', 
                      'no response from', 
                      'Please try again',
                      'InternalError',
                      'ServiceUnavailable', #from SQS docs
                      'Unavailable',
                      'This application is not currently available',
                      'InsufficientInstanceCapacity'
                    ]
    @@amazon_problems = AMAZON_PROBLEMS
      # Returns a list of Amazon service responses which are known to be transient problems. 
      # We have to re-request if we get any of them, because the problem will probably disappear. 
      # By default this method returns the same value as the AMAZON_PROBLEMS const.
    def self.amazon_problems
      @@amazon_problems
    end
    
      # Sets the list of Amazon side problems.  Use in conjunction with the
      # getter to append problems.
    def self.amazon_problems=(problems_list)
      @@amazon_problems = problems_list
    end
    
  end

  module RightAwsBaseInterface
    DEFAULT_SIGNATURE_VERSION = '1'
    
    @@caching = false
    def self.caching
      @@caching
    end
    def self.caching=(caching)
      @@caching = caching
    end

      # Current aws_access_key_id
    attr_reader :aws_access_key_id
      # Last HTTP request object
    attr_reader :last_request
      # Last HTTP response object
    attr_reader :last_response
      # Last AWS errors list (used by AWSErrorHandler)
    attr_accessor :last_errors
      # Last AWS request id (used by AWSErrorHandler)
    attr_accessor :last_request_id
      # Logger object
    attr_accessor :logger
      # Initial params hash
    attr_accessor :params
      # RightHttpConnection instance
    attr_reader :connection
      # Cache
    attr_reader :cache
      # Signature version (all services except s3)
    attr_reader :signature_version

    def init(service_info, aws_access_key_id, aws_secret_access_key, params={}) #:nodoc:
      @params = params
      raise AwsError.new("AWS access keys are required to operate on #{service_info[:name]}") \
        if aws_access_key_id.blank? || aws_secret_access_key.blank?
      @aws_access_key_id     = aws_access_key_id
      @aws_secret_access_key = aws_secret_access_key
      @params[:server]       ||= service_info[:default_host]
      @params[:port]         ||= service_info[:default_port]
      @params[:service]      ||= service_info[:default_service]
      @params[:protocol]     ||= service_info[:default_protocol]
      @params[:multi_thread] ||= defined?(AWS_DAEMON)
      @logger = @params[:logger]
      @logger = RAILS_DEFAULT_LOGGER if !@logger && defined?(RAILS_DEFAULT_LOGGER)
      @logger = Logger.new(STDOUT)   if !@logger
      @logger.info "New #{self.class.name} using #{@params[:multi_thread] ? 'multi' : 'single'}-threaded mode"
      @error_handler = nil
      @cache = {}
      @signature_version = (params[:signature_version] || DEFAULT_SIGNATURE_VERSION).to_s
    end

    # Returns +true+ if the describe_xxx responses are being cached 
    def caching?
      @params.key?(:cache) ? @params[:cache] : @@caching
    end
    
    # Check if the aws function response hits the cache or not.
    # If the cache hits:
    # - raises an +AwsNoChange+ exception if +do_raise+ == +:raise+.
    # - returnes parsed response from the cache if it exists or +true+ otherwise.
    # If the cache miss or the caching is off then returns +false+.
    def cache_hits?(function, response, do_raise=:raise)
      result = false
      if caching?
        function = function.to_sym
        # get rid of requestId (this bad boy was added for API 2008-08-08+ and it is uniq for every response)
        response = response.sub(%r{<requestId>.+?</requestId>}, '')
        response_md5 = MD5.md5(response).to_s
        # check for changes
        unless @cache[function] && @cache[function][:response_md5] == response_md5
          # well, the response is new, reset cache data
          update_cache(function, {:response_md5 => response_md5, 
                                  :timestamp    => Time.now, 
                                  :hits         => 0, 
                                  :parsed       => nil})
        else
          # aha, cache hits, update the data and throw an exception if needed
          @cache[function][:hits] += 1
          if do_raise == :raise
            raise(AwsNoChange, "Cache hit: #{function} response has not changed since "+
                               "#{@cache[function][:timestamp].strftime('%Y-%m-%d %H:%M:%S')}, "+
                               "hits: #{@cache[function][:hits]}.")
          else
            result = @cache[function][:parsed] || true
          end
        end
      end
      result
    end
    
    def update_cache(function, hash)
      (@cache[function.to_sym] ||= {}).merge!(hash) if caching?
    end
    
    def on_exception(options={:raise=>true, :log=>true}) # :nodoc:
      raise if $!.is_a?(AwsNoChange)
      AwsError::on_aws_exception(self, options)
    end
    
      # Return +true+ if this instance works in multi_thread mode and +false+ otherwise.
    def multi_thread
      @params[:multi_thread]
    end

    def request_info_impl(connection, benchblock, request, parser, &block) #:nodoc:
      @connection    = connection
      @last_request  = request[:request]
      @last_response = nil
      response=nil
      blockexception = nil

      if(block != nil)
        # TRB 9/17/07 Careful - because we are passing in blocks, we get a situation where
        # an exception may get thrown in the block body (which is high-level
        # code either here or in the application) but gets caught in the
        # low-level code of HttpConnection.  The solution is not to let any
        # exception escape the block that we pass to HttpConnection::request.
        # Exceptions can originate from code directly in the block, or from user
        # code called in the other block which is passed to response.read_body.
        benchblock.service.add! do
          responsehdr = @connection.request(request) do |response|
          #########
            begin
              @last_response = response
              if response.is_a?(Net::HTTPSuccess)
                @error_handler = nil
                response.read_body(&block)
              else
                @error_handler = AWSErrorHandler.new(self, parser, :errors_list => self.class.amazon_problems) unless @error_handler
                check_result   = @error_handler.check(request)
                if check_result
                  @error_handler = nil
                  return check_result 
                end
                raise AwsError.new(@last_errors, @last_response.code, @last_request_id)
              end
            rescue Exception => e
              blockexception = e
            end
          end
          #########

          #OK, now we are out of the block passed to the lower level
          if(blockexception)
            raise blockexception
          end
          benchblock.xml.add! do
            parser.parse(responsehdr)
          end
          return parser.result
        end
      else
        benchblock.service.add!{ response = @connection.request(request) }
          # check response for errors...
        @last_response = response
        if response.is_a?(Net::HTTPSuccess)
          @error_handler = nil
          benchblock.xml.add! { parser.parse(response) }
          return parser.result
        else
          @error_handler = AWSErrorHandler.new(self, parser, :errors_list => self.class.amazon_problems) unless @error_handler
          check_result   = @error_handler.check(request)
          if check_result
            @error_handler = nil
            return check_result 
          end
          raise AwsError.new(@last_errors, @last_response.code, @last_request_id)
        end
      end
    rescue
      @error_handler = nil
      raise
    end

    def request_cache_or_info(method, link, parser_class, benchblock, use_cache=true) #:nodoc:
      # We do not want to break the logic of parsing hence will use a dummy parser to process all the standard
      # steps (errors checking etc). The dummy parser does nothig - just returns back the params it received.
      # If the caching is enabled and hit then throw  AwsNoChange.
      # P.S. caching works for the whole images list only! (when the list param is blank)
      # check cache
      response, params = request_info(link, RightDummyParser.new)
      cache_hits?(method.to_sym, response.body) if use_cache
      parser = parser_class.new(:logger => @logger)
      benchblock.xml.add!{ parser.parse(response, params) }
      result = block_given? ? yield(parser) : parser.result
      # update parsed data
      update_cache(method.to_sym, :parsed => result) if use_cache
      result
    end

    # Returns Amazons request ID for the latest request
    def last_request_id
      @last_response && @last_response.body.to_s[%r{<requestId>(.+?)</requestId>}] && $1
    end

  end


  # Exception class to signal any Amazon errors. All errors occuring during calls to Amazon's
  # web services raise this type of error.
  # Attribute inherited by RuntimeError:
  #  message    - the text of the error, generally as returned by AWS in its XML response.
  class AwsError < RuntimeError
    
    # either an array of errors where each item is itself an array of [code, message]),
    # or an error string if the error was raised manually, as in <tt>AwsError.new('err_text')</tt>
    attr_reader :errors
    
    # Request id (if exists)
    attr_reader :request_id
    
    # Response HTTP error code
    attr_reader :http_code
    
    def initialize(errors=nil, http_code=nil, request_id=nil)
      @errors      = errors
      @request_id  = request_id
      @http_code   = http_code
      super(@errors.is_a?(Array) ? @errors.map{|code, msg| "#{code}: #{msg}"}.join("; ") : @errors.to_s)
    end
    
    # Does any of the error messages include the regexp +pattern+?
    # Used to determine whether to retry request.
    def include?(pattern)
      if @errors.is_a?(Array)
        @errors.each{ |code, msg| return true if code =~ pattern } 
      else
        return true if @errors_str =~ pattern 
      end
      false
    end
    
    # Generic handler for AwsErrors. +aws+ is the RightAws::S3, RightAws::EC2, or RightAws::SQS
    # object that caused the exception (it must provide last_request and last_response). Supported
    # boolean options are:
    # * <tt>:log</tt> print a message into the log using aws.logger to access the Logger
    # * <tt>:puts</tt> do a "puts" of the error
    # * <tt>:raise</tt> re-raise the error after logging
    def self.on_aws_exception(aws, options={:raise=>true, :log=>true})
 	    # Only log & notify if not user error
      if !options[:raise] || system_error?($!)
        error_text = "#{$!.inspect}\n#{$@}.join('\n')}"
        puts error_text if options[:puts]
          # Log the error
        if options[:log]
          request  = aws.last_request  ? aws.last_request.path :  '-none-'
          response = aws.last_response ? "#{aws.last_response.code} -- #{aws.last_response.message} -- #{aws.last_response.body}" : '-none-'
          aws.logger.error error_text
          aws.logger.error "Request was:  #{request}"
          aws.logger.error "Response was: #{response}"
        end
      end
      raise if options[:raise]  # re-raise an exception
      return nil
    end
    
    # True if e is an AWS system error, i.e. something that is for sure not the caller's fault.
    # Used to force logging.
    def self.system_error?(e)
 	    !e.is_a?(self) || e.message =~ /InternalError|InsufficientInstanceCapacity|Unavailable/
    end

  end


  class AWSErrorHandler
    # 0-100 (%) 
    DEFAULT_CLOSE_ON_4XX_PROBABILITY = 10     
    
    @@reiteration_start_delay = 0.2
    def self.reiteration_start_delay
      @@reiteration_start_delay
    end
    def self.reiteration_start_delay=(reiteration_start_delay)
      @@reiteration_start_delay = reiteration_start_delay
    end

    @@reiteration_time = 5
    def self.reiteration_time
      @@reiteration_time
    end
    def self.reiteration_time=(reiteration_time)
      @@reiteration_time = reiteration_time
    end
    
    @@close_on_error = true 
    def self.close_on_error 
      @@close_on_error 
    end 
    def self.close_on_error=(close_on_error) 
      @@close_on_error = close_on_error 
    end 
 
    @@close_on_4xx_probability = DEFAULT_CLOSE_ON_4XX_PROBABILITY 
    def self.close_on_4xx_probability 
      @@close_on_4xx_probability 
    end 
    def self.close_on_4xx_probability=(close_on_4xx_probability) 
      @@close_on_4xx_probability = close_on_4xx_probability 
    end 
 
    # params: 
    #  :reiteration_time 
    #  :errors_list 
    #  :close_on_error           = true | false 
    #  :close_on_4xx_probability = 1-100 
    def initialize(aws, parser, params={}) #:nodoc:     
      @aws           = aws              # Link to RightEc2 | RightSqs | RightS3 instance
      @parser        = parser           # parser to parse Amazon response
      @started_at    = Time.now
      @stop_at       = @started_at  + (params[:reiteration_time] || @@reiteration_time) 
      @errors_list   = params[:errors_list] || [] 
      @reiteration_delay = @@reiteration_start_delay
      @retries       = 0
      # close current HTTP(S) connection on 5xx, errors from list and 4xx errors 
      @close_on_error           = params[:close_on_error].nil? ? @@close_on_error : params[:close_on_error] 
      @close_on_4xx_probability = params[:close_on_4xx_probability] || @@close_on_4xx_probability       
    end
    
      # Returns false if 
    def check(request)  #:nodoc:
      result           = false
      error_found      = false
      redirect_detected= false
      error_match      = nil
      last_errors_text = ''
      response         = @aws.last_response
      # log error
      request_text_data = "#{request[:server]}:#{request[:port]}#{request[:request].path}"
      # is this a redirect?
      # yes!
      if response.is_a?(Net::HTTPRedirection)
        redirect_detected = true 
      else
        # no, it's an error ...
        @aws.logger.warn("##### #{@aws.class.name} returned an error: #{response.code} #{response.message}\n#{response.body} #####")
        @aws.logger.warn("##### #{@aws.class.name} request: #{request_text_data} ####")
      end
        # Check response body: if it is an Amazon XML document or not:
      if redirect_detected || (response.body && response.body[/<\?xml/])   # ... it is a xml document
        @aws.class.bench_xml.add! do
          error_parser = RightErrorResponseParser.new
          error_parser.parse(response)
          @aws.last_errors     = error_parser.errors
          @aws.last_request_id = error_parser.requestID
          last_errors_text     = @aws.last_errors.flatten.join("\n")
          # on redirect :
          if redirect_detected
            location = response['location']
            # ... log information and ...
            @aws.logger.info("##### #{@aws.class.name} redirect requested: #{response.code} #{response.message} #####")
            @aws.logger.info("##### New location: #{location} #####")
            # ... fix the connection data
            request[:server]   = URI.parse(location).host
            request[:protocol] = URI.parse(location).scheme
            request[:port]     = URI.parse(location).port
          end
        end
      else                               # ... it is not a xml document(probably just a html page?)
        @aws.last_errors     = [[response.code, "#{response.message} (#{request_text_data})"]]
        @aws.last_request_id = '-undefined-'
        last_errors_text     = response.message
      end
        # now - check the error
      unless redirect_detected
        @errors_list.each do |error_to_find|
          if last_errors_text[/#{error_to_find}/i]
            error_found = true
            error_match = error_to_find
            @aws.logger.warn("##### Retry is needed, error pattern match: #{error_to_find} #####")
            break
          end
        end
      end
        # check the time has gone from the first error come
      if redirect_detected || error_found
        # Close the connection to the server and recreate a new one. 
        # It may have a chance that one server is a semi-down and reconnection 
        # will help us to connect to the other server 
        if !redirect_detected && @close_on_error
          @aws.connection.finish "#{self.class.name}: error match to pattern '#{error_match}'" 
        end 
                 
        if (Time.now < @stop_at)
          @retries += 1
          unless redirect_detected
            @aws.logger.warn("##### Retry ##{@retries} is being performed. Sleeping for #{@reiteration_delay} sec. Whole time: #{Time.now-@started_at} sec ####")
            sleep @reiteration_delay 
            @reiteration_delay *= 2

            # Always make sure that the fp is set to point to the beginning(?)
            # of the File/IO. TODO: it assumes that offset is 0, which is bad.
            if(request[:request].body_stream && request[:request].body_stream.respond_to?(:pos))
              begin
                request[:request].body_stream.pos = 0
              rescue Exception => e
                @logger.warn("Retry may fail due to unable to reset the file pointer" +
                             " -- #{self.class.name} : #{e.inspect}")
              end
            end
          else
            @aws.logger.info("##### Retry ##{@retries} is being performed due to a redirect.  ####")
          end
          result = @aws.request_info(request, @parser)
        else
          @aws.logger.warn("##### Ooops, time is over... ####")
        end 
      # aha, this is unhandled error: 
      elsif @close_on_error 
        # Is this a 5xx error ? 
        if @aws.last_response.code.to_s[/^5\d\d$/] 
          @aws.connection.finish "#{self.class.name}: code: #{@aws.last_response.code}: '#{@aws.last_response.message}'" 
        # Is this a 4xx error ? 
        elsif @aws.last_response.code.to_s[/^4\d\d$/] && @close_on_4xx_probability > rand(100) 
          @aws.connection.finish "#{self.class.name}: code: #{@aws.last_response.code}: '#{@aws.last_response.message}', " + 
                                 "probability: #{@close_on_4xx_probability}%"           
        end
      end
      result
    end
    
  end


  #-----------------------------------------------------------------

  class RightSaxParserCallback #:nodoc:
    def self.include_callback 
      include XML::SaxParser::Callbacks       
    end 
    def initialize(right_aws_parser) 
      @right_aws_parser = right_aws_parser 
    end 
    def on_start_element(name, attr_hash) 
      @right_aws_parser.tag_start(name, attr_hash) 
    end   
    def on_characters(chars) 
      @right_aws_parser.text(chars) 
    end 
    def on_end_element(name) 
      @right_aws_parser.tag_end(name) 
    end 
    def on_start_document; end 
    def on_comment(msg); end 
    def on_processing_instruction(target, data); end 
    def on_cdata_block(cdata); end 
    def on_end_document; end 
  end 
 
  class RightAWSParser  #:nodoc:
      # default parsing library 
    DEFAULT_XML_LIBRARY = 'rexml' 
      # a list of supported parsers 
    @@supported_xml_libs = [DEFAULT_XML_LIBRARY, 'libxml'] 
     
    @@xml_lib = DEFAULT_XML_LIBRARY # xml library name: 'rexml' | 'libxml' 
    def self.xml_lib
      @@xml_lib
    end
    def self.xml_lib=(new_lib_name)
      @@xml_lib = new_lib_name
    end
    
    attr_accessor :result
    attr_reader   :xmlpath
    attr_accessor :xml_lib
    
    def initialize(params={})
      @xmlpath = ''
      @result  = false
      @text    = ''
      @xml_lib = params[:xml_lib] || @@xml_lib
      @logger  = params[:logger]
      reset
    end
    def tag_start(name, attributes)
      @text = ''
      tagstart(name, attributes)
      @xmlpath += @xmlpath.empty? ? name : "/#{name}"
    end
    def tag_end(name)
      @xmlpath[/^(.*?)\/?#{name}$/]
      @xmlpath = $1
      tagend(name)
    end
    def text(text)
      @text += text
      tagtext(text)
    end
      # Parser method.
      # Params:
      #   xml_text         - xml message text(String) or Net:HTTPxxx instance (response)
      #   params[:xml_lib] - library name: 'rexml' | 'libxml'
    def parse(xml_text, params={})
        # Get response body
      xml_text = xml_text.body unless xml_text.is_a?(String)
      @xml_lib = params[:xml_lib] || @xml_lib
        # check that we had no problems with this library otherwise use default 
      @xml_lib = DEFAULT_XML_LIBRARY unless @@supported_xml_libs.include?(@xml_lib)       
        # load xml library
      if @xml_lib=='libxml' && !defined?(XML::SaxParser)
        begin
          require 'xml/libxml'
          # is it new ? - Setup SaxParserCallback 
          if XML::Parser::VERSION >= '0.5.1.0'
            RightSaxParserCallback.include_callback 
          end           
        rescue LoadError => e
          @@supported_xml_libs.delete(@xml_lib) 
          @xml_lib = DEFAULT_XML_LIBRARY           
          if @logger
            @logger.error e.inspect
            @logger.error e.backtrace
            @logger.info "Can not load 'libxml' library. '#{DEFAULT_XML_LIBRARY}' is used for parsing." 
          end
        end
      end
        # Parse the xml text
      case @xml_lib
      when 'libxml'  
        xml        = XML::SaxParser.new 
        xml.string = xml_text 
        # check libxml-ruby version 
        if XML::Parser::VERSION >= '0.5.1.0'
          xml.callbacks = RightSaxParserCallback.new(self) 
        else 
          xml.on_start_element{|name, attr_hash| self.tag_start(name, attr_hash)} 
          xml.on_characters{   |text|            self.text(text)} 
          xml.on_end_element{  |name|            self.tag_end(name)} 
        end 
        xml.parse
      else
        REXML::Document.parse_stream(xml_text, self)
      end
    end
      # Parser must have a lots of methods 
      # (see /usr/lib/ruby/1.8/rexml/parsers/streamparser.rb)
      # We dont need most of them in RightAWSParser and method_missing helps us
      # to skip their definition
    def method_missing(method, *params)
        # if the method is one of known - just skip it ...
      return if [:comment, :attlistdecl, :notationdecl, :elementdecl, 
                 :entitydecl, :cdata, :xmldecl, :attlistdecl, :instruction, 
                 :doctype].include?(method)
        # ... else - call super to raise an exception
      super(method, params)
    end
      # the functions to be overriden by children (if nessesery)
    def reset                     ; end
    def tagstart(name, attributes); end
    def tagend(name)              ; end
    def tagtext(text)             ; end
  end

  #-----------------------------------------------------------------
  #      PARSERS: Errors
  #-----------------------------------------------------------------

#<Error>
#  <Code>TemporaryRedirect</Code>
#  <Message>Please re-send this request to the specified temporary endpoint. Continue to use the original request endpoint for future requests.</Message>
#  <RequestId>FD8D5026D1C5ABA3</RequestId>
#  <Endpoint>bucket-for-k.s3-external-3.amazonaws.com</Endpoint>
#  <HostId>ItJy8xPFPli1fq/JR3DzQd3iDvFCRqi1LTRmunEdM1Uf6ZtW2r2kfGPWhRE1vtaU</HostId>
#  <Bucket>bucket-for-k</Bucket>
#</Error>

  class RightErrorResponseParser < RightAWSParser #:nodoc:
    attr_accessor :errors  # array of hashes: error/message
    attr_accessor :requestID
#    attr_accessor :endpoint, :host_id, :bucket
    def tagend(name)
      case name
        when 'RequestID' ; @requestID = @text
        when 'Code'      ; @code      = @text
        when 'Message'   ; @message   = @text
#       when 'Endpoint'  ; @endpoint  = @text
#       when 'HostId'    ; @host_id   = @text
#       when 'Bucket'    ; @bucket    = @text
        when 'Error'     ; @errors   << [ @code, @message ]
      end
    end
    def reset
      @errors = []
    end
  end

  # Dummy parser - does nothing
  # Returns the original params back
  class RightDummyParser  # :nodoc:
    attr_accessor :result
    def parse(response, params={})
      @result = [response, params]
    end
  end

  class RightHttp2xxParser < RightAWSParser # :nodoc:
    def parse(response)
      @result = response.is_a?(Net::HTTPSuccess)
    end
  end

end

