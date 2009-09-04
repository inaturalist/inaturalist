#
# Copyright (c) 2008 RightScale Inc
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

module RightAws

  # = RightAws::AcfInterface -- RightScale Amazon's CloudFront interface
  # The AcfInterface class provides a complete interface to Amazon's
  # CloudFront service.
  #
  # For explanations of the semantics of each call, please refer to
  # Amazon's documentation at
  # http://developer.amazonwebservices.com/connect/kbcategory.jspa?categoryID=211
  #
  # Example:
  #
  #  acf = RightAws::AcfInterface.new('1E3GDYEOGFJPIT7XXXXXX','hgTHt68JY07JKUY08ftHYtERkjgtfERn57XXXXXX')
  #
  #  list = acf.list_distributions #=>
  #    [{:status             => "Deployed",
  #      :domain_name        => "d74zzrxmpmygb.6hops.net",
  #      :aws_id             => "E4U91HCJHGXVC",
  #      :origin             => "my-bucket.s3.amazonaws.com",
  #      :cnames             => ["x1.my-awesome-site.net", "x1.my-awesome-site.net"]
  #      :comment            => "My comments",
  #      :last_modified_time => Wed Sep 10 17:00:04 UTC 2008 }, ..., {...} ]
  #
  #  distibution = list.first
  #
  #  info = acf.get_distribution(distibution[:aws_id]) #=>
  #    {:enabled            => true,
  #     :caller_reference   => "200809102100536497863003",
  #     :e_tag              => "E39OHHU1ON65SI",
  #     :status             => "Deployed",
  #     :domain_name        => "d3dxv71tbbt6cd.6hops.net",
  #     :cnames             => ["web1.my-awesome-site.net", "web2.my-awesome-site.net"]
  #     :aws_id             => "E2REJM3VUN5RSI",
  #     :comment            => "Woo-Hoo!",
  #     :origin             => "my-bucket.s3.amazonaws.com",
  #     :last_modified_time => Wed Sep 10 17:00:54 UTC 2008 }
  #
  #  config = acf.get_distribution_config(distibution[:aws_id]) #=>
  #    {:enabled          => true,
  #     :caller_reference => "200809102100536497863003",
  #     :e_tag            => "E39OHHU1ON65SI",
  #     :cnames           => ["web1.my-awesome-site.net", "web2.my-awesome-site.net"]
  #     :comment          => "Woo-Hoo!",
  #     :origin           => "my-bucket.s3.amazonaws.com"}
  #
  #  config[:comment] = 'Olah-lah!'
  #  config[:enabled] = false
  #  config[:cnames] << "web3.my-awesome-site.net"
  #
  #  acf.set_distribution_config(distibution[:aws_id], config) #=> true
  #
  class AcfInterface < RightAwsBase
    
    include RightAwsBaseInterface

    API_VERSION      = "2008-06-30"
    DEFAULT_HOST     = 'cloudfront.amazonaws.com'
    DEFAULT_PORT     = 443
    DEFAULT_PROTOCOL = 'https'
    DEFAULT_PATH     = '/'

    @@bench = AwsBenchmarkingBlock.new
    def self.bench_xml
      @@bench.xml
    end
    def self.bench_service
      @@bench.service
    end

    # Create a new handle to a CloudFront account. All handles share the same per process or per thread
    # HTTP connection to CloudFront. Each handle is for a specific account. The params have the
    # following options:
    # * <tt>:server</tt>: CloudFront service host, default: DEFAULT_HOST
    # * <tt>:port</tt>: CloudFront service port, default: DEFAULT_PORT
    # * <tt>:protocol</tt>: 'http' or 'https', default: DEFAULT_PROTOCOL
    # * <tt>:multi_thread</tt>: true=HTTP connection per thread, false=per process
    # * <tt>:logger</tt>: for log messages, default: RAILS_DEFAULT_LOGGER else STDOUT
    # * <tt>:cache</tt>: true/false: caching for list_distributions method, default: false.
    #
    #  acf = RightAws::AcfInterface.new('1E3GDYEOGFJPIT7XXXXXX','hgTHt68JY07JKUY08ftHYtERkjgtfERn57XXXXXX',
    #    {:multi_thread => true, :logger => Logger.new('/tmp/x.log')}) #=>  #<RightAws::AcfInterface::0xb7b3c30c>
    #
    def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
      init({ :name             => 'ACF',
             :default_host     => ENV['ACF_URL'] ? URI.parse(ENV['ACF_URL']).host   : DEFAULT_HOST,
             :default_port     => ENV['ACF_URL'] ? URI.parse(ENV['ACF_URL']).port   : DEFAULT_PORT,
             :default_service  => ENV['ACF_URL'] ? URI.parse(ENV['ACF_URL']).path   : DEFAULT_PATH,
             :default_protocol => ENV['ACF_URL'] ? URI.parse(ENV['ACF_URL']).scheme : DEFAULT_PROTOCOL },
           aws_access_key_id     || ENV['AWS_ACCESS_KEY_ID'], 
           aws_secret_access_key || ENV['AWS_SECRET_ACCESS_KEY'], 
           params)
    end

    #-----------------------------------------------------------------
    #      Requests
    #-----------------------------------------------------------------

    # Generates request hash for REST API.
    def generate_request(method, path, body=nil, headers={})  # :nodoc:
      headers['content-type'] ||= 'text/xml' if body
      headers['date'] = Time.now.httpdate
      # Auth
      signature = AwsUtils::sign(@aws_secret_access_key, headers['date'])
      headers['Authorization'] = "AWS #{@aws_access_key_id}:#{signature}"
      # Request
      path    = "#{@params[:default_service]}/#{API_VERSION}/#{path}"
      request = "Net::HTTP::#{method.capitalize}".constantize.new(path)
      request.body = body if body
      # Set request headers
      headers.each { |key, value| request[key.to_s] = value }
      # prepare output hash
      { :request  => request, 
        :server   => @params[:server],
        :port     => @params[:port],
        :protocol => @params[:protocol] }
      end
      
      # Sends request to Amazon and parses the response.
      # Raises AwsError if any banana happened.
    def request_info(request, parser, &block) # :nodoc:
      thread = @params[:multi_thread] ? Thread.current : Thread.main
      thread[:acf_connection] ||= Rightscale::HttpConnection.new(:exception => RightAws::AwsError, :logger => @logger)
      request_info_impl(thread[:acf_connection], @@bench, request, parser, &block)
    end

    #-----------------------------------------------------------------
    #      Helpers:
    #-----------------------------------------------------------------

    def self.escape(text) # :nodoc:
      REXML::Text::normalize(text)
    end

    def self.unescape(text) # :nodoc:
      REXML::Text::unnormalize(text)
    end

    def xmlns # :nodoc:
      %Q{"http://#{@params[:server]}/doc/#{API_VERSION}/"}
    end

    def generate_call_reference # :nodoc:
      result = Time.now.strftime('%Y%m%d%H%M%S')
      10.times{ result << rand(10).to_s }
      result
    end

    def merge_headers(hash) # :nodoc:
      hash[:location] = @last_response['Location'] if @last_response['Location']
      hash[:e_tag]    = @last_response['ETag']     if @last_response['ETag']
      hash
    end

    #-----------------------------------------------------------------
    #      API Calls:
    #-----------------------------------------------------------------

    # List distributions.
    # Returns an array of distributions or RightAws::AwsError exception.
    #
    #  acf.list_distributions #=>
    #    [{:status             => "Deployed",
    #      :domain_name        => "d74zzrxmpmygb.6hops.net",
    #      :aws_id             => "E4U91HCJHGXVC",
    #      :cnames             => ["web1.my-awesome-site.net", "web2.my-awesome-site.net"]
    #      :origin             => "my-bucket.s3.amazonaws.com",
    #      :comment            => "My comments",
    #      :last_modified_time => Wed Sep 10 17:00:04 UTC 2008 }, ..., {...} ]
    #
    def list_distributions
      request_hash = generate_request('GET', 'distribution')
      request_cache_or_info :list_distributions, request_hash,  AcfDistributionListParser, @@bench
    end

    # Create a new distribution.
    # Returns the just created distribution or RightAws::AwsError exception.
    #
    #  acf.create_distribution('bucket-for-k-dzreyev.s3.amazonaws.com', 'Woo-Hoo!', ['web1.my-awesome-site.net'] ) #=>
    #    {:comment            => "Woo-Hoo!",
    #     :enabled            => true,
    #     :location           => "https://cloudfront.amazonaws.com/2008-06-30/distribution/E2REJM3VUN5RSI",
    #     :status             => "InProgress",
    #     :aws_id             => "E2REJM3VUN5RSI",
    #     :domain_name        => "d3dxv71tbbt6cd.6hops.net",
    #     :origin             => "my-bucket.s3.amazonaws.com",
    #     :cnames             => ["web1.my-awesome-site.net"]
    #     :last_modified_time => Wed Sep 10 17:00:54 UTC 2008,
    #     :caller_reference   => "200809102100536497863003"}
    #
    def create_distribution(origin, comment='', enabled=true, cnames=[], caller_reference=nil)
      # join CNAMES
      cnames_str = ''
      unless cnames.blank?
        cnames.to_a.each { |cname| cnames_str += "\n           <CNAME>#{cname}</CNAME>" }
      end
      # reference
      caller_reference ||= generate_call_reference
      body = <<-EOXML
        <?xml version="1.0" encoding="UTF-8"?>
        <DistributionConfig xmlns=#{xmlns}>
           <Origin>#{origin}</Origin>
           <CallerReference>#{caller_reference}</CallerReference>
           #{cnames_str.lstrip}
           <Comment>#{AcfInterface::escape(comment.to_s)}</Comment>
           <Enabled>#{enabled}</Enabled>
        </DistributionConfig>
      EOXML
      request_hash = generate_request('POST', 'distribution', body.strip)
      merge_headers(request_info(request_hash, AcfDistributionParser.new))
    end

    # Get a distribution's information.
    # Returns a distribution's information or RightAws::AwsError exception.
    #
    #  acf.get_distribution('E2REJM3VUN5RSI') #=>
    #    {:enabled            => true,
    #     :caller_reference   => "200809102100536497863003",
    #     :e_tag              => "E39OHHU1ON65SI",
    #     :status             => "Deployed",
    #     :domain_name        => "d3dxv71tbbt6cd.6hops.net",
    #     :cnames             => ["web1.my-awesome-site.net", "web2.my-awesome-site.net"]
    #     :aws_id             => "E2REJM3VUN5RSI",
    #     :comment            => "Woo-Hoo!",
    #     :origin             => "my-bucket.s3.amazonaws.com",
    #     :last_modified_time => Wed Sep 10 17:00:54 UTC 2008 }
    #
    def get_distribution(aws_id)
      request_hash = generate_request('GET', "distribution/#{aws_id}")
      merge_headers(request_info(request_hash, AcfDistributionParser.new))
    end

    # Get a distribution's configuration.
    # Returns a distribution's configuration or RightAws::AwsError exception.
    #
    #  acf.get_distribution_config('E2REJM3VUN5RSI') #=>
    #    {:enabled          => true,
    #     :caller_reference => "200809102100536497863003",
    #     :e_tag            => "E39OHHU1ON65SI",
    #     :cnames           => ["web1.my-awesome-site.net", "web2.my-awesome-site.net"]
    #     :comment          => "Woo-Hoo!",
    #     :origin           => "my-bucket.s3.amazonaws.com"}
    #
    def get_distribution_config(aws_id)
      request_hash = generate_request('GET', "distribution/#{aws_id}/config")
      merge_headers(request_info(request_hash, AcfDistributionConfigParser.new))
    end

    # Set a distribution's configuration 
    # (the :origin and the :caller_reference cannot be changed).
    # Returns +true+ on success or RightAws::AwsError exception.
    #
    #  config = acf.get_distribution_config('E2REJM3VUN5RSI') #=>
    #    {:enabled          => true,
    #     :caller_reference => "200809102100536497863003",
    #     :e_tag            => "E39OHHU1ON65SI",
    #     :cnames           => ["web1.my-awesome-site.net", "web2.my-awesome-site.net"]
    #     :comment          => "Woo-Hoo!",
    #     :origin           => "my-bucket.s3.amazonaws.com"}
    #  config[:comment] = 'Olah-lah!'
    #  config[:enabled] = false
    #  acf.set_distribution_config('E2REJM3VUN5RSI', config) #=> true
    #
    def set_distribution_config(aws_id, config)
      # join CNAMES
      cnames_str = ''
      unless config[:cnames].blank?
        config[:cnames].to_a.each { |cname| cnames_str += "\n           <CNAME>#{cname}</CNAME>" }
      end
      # format request's XML body
      body = <<-EOXML
        <?xml version="1.0" encoding="UTF-8"?>
        <DistributionConfig xmlns=#{xmlns}>
           <Origin>#{config[:origin]}</Origin>
           <CallerReference>#{config[:caller_reference]}</CallerReference>
           #{cnames_str.lstrip}
           <Comment>#{AcfInterface::escape(config[:comment].to_s)}</Comment>
           <Enabled>#{config[:enabled]}</Enabled>
        </DistributionConfig>
      EOXML
      request_hash = generate_request('PUT', "distribution/#{aws_id}/config", body.strip,
                                      'If-Match' => config[:e_tag])
      request_info(request_hash, RightHttp2xxParser.new)
    end

    # Delete a distribution. The enabled distribution cannot be deleted.
    # Returns +true+ on success or RightAws::AwsError exception.
    #
    #  acf.delete_distribution('E2REJM3VUN5RSI', 'E39OHHU1ON65SI') #=> true
    #
    def delete_distribution(aws_id, e_tag)
      request_hash = generate_request('DELETE', "distribution/#{aws_id}", nil,
                                      'If-Match' => e_tag)
      request_info(request_hash, RightHttp2xxParser.new)
    end

    #-----------------------------------------------------------------
    #      PARSERS:
    #-----------------------------------------------------------------

    class AcfDistributionListParser < RightAWSParser # :nodoc:
      def reset
        @result = []
      end
      def tagstart(name, attributes)
        @distribution = { :cnames => [] } if name == 'DistributionSummary'
      end
      def tagend(name)
        case name
          when 'Id'                  then @distribution[:aws_id]             = @text
          when 'Status'              then @distribution[:status]             = @text
          when 'LastModifiedTime'    then @distribution[:last_modified_time] = Time.parse(@text)
          when 'DomainName'          then @distribution[:domain_name]        = @text
          when 'Origin'              then @distribution[:origin]             = @text
          when 'Comment'             then @distribution[:comment]            = AcfInterface::unescape(@text)
          when 'CNAME'               then @distribution[:cnames]            << @text
          when 'DistributionSummary' then @result << @distribution
        end
      end
    end

    class AcfDistributionParser < RightAWSParser # :nodoc:
      def reset
        @result = { :cnames => [] }
      end
      def tagend(name)
        case name
          when 'Id'               then @result[:aws_id]             = @text
          when 'Status'           then @result[:status]             = @text
          when 'LastModifiedTime' then @result[:last_modified_time] = Time.parse(@text)
          when 'DomainName'       then @result[:domain_name]        = @text
          when 'Origin'           then @result[:origin]             = @text
          when 'CallerReference'  then @result[:caller_reference]   = @text
          when 'Comment'          then @result[:comment]            = AcfInterface::unescape(@text)
          when 'Enabled'          then @result[:enabled]            = @text == 'true' ? true : false
          when 'CNAME'            then @result[:cnames]            << @text
        end
      end
    end

    class AcfDistributionConfigParser < RightAWSParser # :nodoc:
      def reset
        @result = { :cnames => [] }
      end
      def tagend(name)
        case name
          when 'Origin'           then @result[:origin]           = @text
          when 'CallerReference'  then @result[:caller_reference] = @text
          when 'Comment'          then @result[:comment]          = AcfInterface::unescape(@text)
          when 'Enabled'          then @result[:enabled]          = @text == 'true' ? true : false
          when 'CNAME'            then @result[:cnames]          << @text
        end
      end
    end

  end
end
