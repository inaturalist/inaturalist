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

require "right_aws"

module RightAws

  class SdbInterface < RightAwsBase
    
    include RightAwsBaseInterface

    DEFAULT_HOST      = 'sdb.amazonaws.com'
    DEFAULT_PORT      = 443
    DEFAULT_PROTOCOL  = 'https'
    API_VERSION       = '2007-11-07'
    DEFAULT_NIL_REPRESENTATION = 'nil'

    @@bench = AwsBenchmarkingBlock.new
    def self.bench_xml; @@bench.xml;     end
    def self.bench_sdb; @@bench.service; end

    attr_reader :last_query_expression

    # Creates new RightSdb instance.
    #
    # Params:
    #    { :server       => 'sdb.amazonaws.com'  # Amazon service host: 'sdb.amazonaws.com'(default)
    #      :port         => 443                  # Amazon service port: 80 or 443(default)
    #      :protocol     => 'https'              # Amazon service protocol: 'http' or 'https'(default)
    #      :signature_version => '0'             # The signature version : '0' or '1'(default)
    #      :multi_thread => true|false           # Multi-threaded (connection per each thread): true or false(default)
    #      :logger       => Logger Object        # Logger instance: logs to STDOUT if omitted 
    #      :nil_representation => 'mynil'}       # interpret Ruby nil as this string value; i.e. use this string in SDB to represent Ruby nils (default is the string 'nil')
    #      
    # Example:
    # 
    #  sdb = RightAws::SdbInterface.new('1E3GDYEOGFJPIT7XXXXXX','hgTHt68JY07JKUY08ftHYtERkjgtfERn57XXXXXX', {:multi_thread => true, :logger => Logger.new('/tmp/x.log')}) #=> #<RightSdb:0xa6b8c27c>
    #  
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/
    #
    def initialize(aws_access_key_id=nil, aws_secret_access_key=nil, params={})
      @nil_rep = params[:nil_representation] ? params[:nil_representation] : DEFAULT_NIL_REPRESENTATION
      params.delete(:nil_representation)
      init({ :name             => 'SDB', 
             :default_host     => ENV['SDB_URL'] ? URI.parse(ENV['SDB_URL']).host   : DEFAULT_HOST, 
             :default_port     => ENV['SDB_URL'] ? URI.parse(ENV['SDB_URL']).port   : DEFAULT_PORT, 
             :default_protocol => ENV['SDB_URL'] ? URI.parse(ENV['SDB_URL']).scheme : DEFAULT_PROTOCOL }, 
           aws_access_key_id     || ENV['AWS_ACCESS_KEY_ID'], 
           aws_secret_access_key || ENV['AWS_SECRET_ACCESS_KEY'], 
           params)
    end
    
    #-----------------------------------------------------------------
    #      Requests
    #-----------------------------------------------------------------
    def generate_request(action, params={}) #:nodoc:
      # remove empty params from request
      params.delete_if {|key,value| value.nil? }
      #params_string  = params.to_a.collect{|key,val| key + "=#{CGI::escape(val.to_s)}" }.join("&")
      # prepare service data
      service_hash = {"Action"            => action,
                      "AWSAccessKeyId"    => @aws_access_key_id,
                      "Version"           => API_VERSION,
                      "Timestamp"         => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
                      "SignatureVersion"  => signature_version }
      service_hash.update(params)
      # prepare string to sight
      string_to_sign = case signature_version
                       when '0' then service_hash["Action"] + service_hash["Timestamp"]
                       when '1' then service_hash.sort{|a,b| (a[0].to_s.downcase)<=>(b[0].to_s.downcase)}.to_s
                       end
      service_hash.update('Signature' =>  AwsUtils::sign(@aws_secret_access_key, string_to_sign))
      service_string = service_hash.to_a.collect{|key,val| key + "=#{CGI::escape(val.to_s)}" }.join("&")
      #
      # use POST method if the length of the query string is too large
      # see http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/MakingRESTRequests.html
      if service_string.size > 2000
        request      = Net::HTTP::Post.new("/")
        request.body = service_string
      else
        #params_string = "&#{params_string}" unless params_string.blank?
        request       = Net::HTTP::Get.new("/?#{service_string}")
      end
      # prepare output hash
      { :request  => request, 
        :server   => @params[:server],
        :port     => @params[:port],
        :protocol => @params[:protocol] }
    end

    # Sends request to Amazon and parses the response
    # Raises AwsError if any banana happened
    def request_info(request, parser)  #:nodoc:
      thread = @params[:multi_thread] ? Thread.current : Thread.main
      thread[:sdb_connection] ||= Rightscale::HttpConnection.new(:exception => AwsError, :logger => @logger)
      request_info_impl(thread[:sdb_connection], @@bench, request, parser)
    end

    # Prepare attributes for putting.
    # (used by put_attributes)
    def pack_attributes(attributes, replace = false) #:nodoc:
      result = {}
      if attributes
        idx = 0
        skip_values = attributes.is_a?(Array)
        attributes.each do |attribute, values|
          # set replacement attribute
          result["Attribute.#{idx}.Replace"] = 'true' if replace
          # pack Name/Value
          unless values.nil?
            Array(values).each do |value|
              result["Attribute.#{idx}.Name"]  = attribute
              result["Attribute.#{idx}.Value"] = ruby_to_sdb(value) unless skip_values
              idx += 1
            end
          else
            result["Attribute.#{idx}.Name"] = attribute
            result["Attribute.#{idx}.Value"] = ruby_to_sdb(nil) unless skip_values
            idx += 1
          end
        end
      end
      result
    end
    
    # Use this helper to manually escape the fields in the query expressions. 
    # To escape the single quotes and backslashes and to wrap the string into the single quotes.
    # 
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API.html
    #
    def escape(value)
      %Q{'#{value.to_s.gsub(/(['\\])/){ "\\#{$1}" }}'} if value
    end
    
    # Convert a Ruby language value to a SDB value by replacing Ruby nil with the user's chosen string representation of nil.
    # Non-nil values are unaffected by this filter.
    def ruby_to_sdb(value)
      value.nil? ? @nil_rep : value
    end
    
    # Convert a SDB value to a Ruby language value by replacing the user's chosen string representation of nil with Ruby nil.
    # Values are unaffected by this filter unless they match the nil representation exactly.
    def sdb_to_ruby(value)
      value.eql?(@nil_rep) ? nil : value
    end
    
    # Create query expression from an array.
    # (similar to ActiveRecord::Base#find using :conditions => ['query', param1, .., paramN])
    #
    def query_expression_from_array(params) #:nodoc:
      unless params.blank?
        query = params.shift.to_s
        query.gsub(/(\\)?(\?)/) do
          if $1 # if escaped '\?' is found - replace it by '?' without backslash
            "?"
          else  # well, if no backslash precedes '?' then replace it by next param from the list
            escape(params.shift)
          end
        end
      end
    end
    
    # Retrieve a list of SDB domains from Amazon.
    # 
    # Returns a hash:
    #   { :domains     => [domain1, ..., domainN],
    #     :next_token => string || nil,
    #     :box_usage   => string,
    #     :request_id  => string }
    #     
    # Example:
    # 
    #  sdb = RightAws::SdbInterface.new
    #  sdb.list_domains  #=> { :box_usage  => "0.0000071759",
    #                          :request_id => "976709f9-0111-2345-92cb-9ce90acd0982",
    #                          :domains    => ["toys", "dolls"]}
    # 
    # If a block is given, this method yields to it.  If the block returns true, list_domains will continue looping the request.  If the block returns false,
    # list_domains will end.
    # 
    #   sdb.list_domains(10) do |result|   # list by 10 domains per iteration
    #     puts result.inspect
    #     true
    #   end
    #
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API_ListDomains.html
    #
    def list_domains(max_number_of_domains = nil, next_token = nil )
      request_params = { 'MaxNumberOfDomains' => max_number_of_domains,
                         'NextToken'          => next_token }
      link   = generate_request("ListDomains", request_params)
      result = request_info(link, QSdbListDomainParser.new)
      # return result if no block given
      return result unless block_given?
      # loop if block if given
      begin
        # the block must return true if it wanna continue 
        break unless yield(result) && result[:next_token]
        # make new request
        request_params['NextToken'] = result[:next_token]
        link   = generate_request("ListDomains", request_params)
        result = request_info(link, QSdbListDomainParser.new)
      end while true
    rescue Exception
      on_exception
    end
    
    # Create new SDB domain at Amazon.
    # 
    # Returns a hash: { :box_usage, :request_id } on success or an exception on error.
    # (Amazon raises no errors if the domain already exists).
    # 
    # Example:
    # 
    #  sdb = RightAws::SdbInterface.new
    #  sdb.create_domain('toys') # => { :box_usage  => "0.0000071759",
    #                                   :request_id => "976709f9-0111-2345-92cb-9ce90acd0982" }
    #
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API_CreateDomain.html
    def create_domain(domain_name)
      link = generate_request("CreateDomain",
                              'DomainName' => domain_name)
      request_info(link, QSdbSimpleParser.new)
    rescue Exception
      on_exception
    end

    # Delete SDB domain at Amazon.
    # 
    # Returns a hash: { :box_usage, :request_id } on success or an exception on error.
    # (Amazon raises no errors if the domain does not exist).
    # 
    # Example:
    # 
    #  sdb = RightAws::SdbInterface.new
    #  sdb.delete_domain('toys') # => { :box_usage  => "0.0000071759",
    #                                   :request_id => "976709f9-0111-2345-92cb-9ce90acd0982" }
    #
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API_DeleteDomain.html
    #
    def delete_domain(domain_name)
      link = generate_request("DeleteDomain",
                              'DomainName' => domain_name)
      request_info(link, QSdbSimpleParser.new)
    rescue Exception
      on_exception
    end
    
    # Add/Replace item attributes.
    # 
    # Params:
    #  domain_name = DomainName
    #  item_name   = ItemName
    #  attributes  = {
    #    'nameA' => [valueA1,..., valueAN],
    #    ...
    #    'nameZ' => [valueZ1,..., valueZN]
    #  }
    #  replace = :replace | any other value to skip replacement
    #  
    # Returns a hash: { :box_usage, :request_id } on success or an exception on error. 
    # (Amazon raises no errors if the attribute was not overridden, as when the :replace param is unset).
    # 
    # Example:
    # 
    #  sdb = RightAws::SdbInterface.new
    #  sdb.create_domain 'family'
    #  
    #  attributes = {}
    #  # create attributes for Jon and Silvia
    #  attributes['Jon']    = %w{ car beer }
    #  attributes['Silvia'] = %w{ beetle rolling_pin kids } 
    #  sdb.put_attributes 'family', 'toys', attributes   #=> ok
    #  # now: Jon=>[car, beer], Silvia=>[beetle, rolling_pin, kids]
    #  
    #  # add attributes to Jon
    #  attributes.delete('Silvia')
    #  attributes['Jon'] = %w{ girls pub }
    #  sdb.put_attributes 'family', 'toys', attributes   #=> ok
    #  # now: Jon=>[car, beer, girls, pub], Silvia=>[beetle, rolling_pin, kids]
    #  
    #  # replace attributes for Jon and add to a cat (the cat had no attributes before)
    #  attributes['Jon'] = %w{ vacuum_cleaner hammer spade }
    #  attributes['cat'] = %w{ mouse clew Jons_socks }
    #  sdb.put_attributes 'family', 'toys', attributes, :replace #=> ok
    #  # now: Jon=>[vacuum_cleaner, hammer, spade], Silvia=>[beetle, rolling_pin, kids], cat=>[mouse, clew, Jons_socks]
    #
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API_PutAttributes.html
    #
    def put_attributes(domain_name, item_name, attributes, replace = false)
      params = { 'DomainName' => domain_name,
                 'ItemName'   => item_name }.merge(pack_attributes(attributes, replace))
      link = generate_request("PutAttributes", params)
      request_info( link, QSdbSimpleParser.new )
    rescue Exception
      on_exception
    end
    
    # Retrieve SDB item's attribute(s).
    # 
    # Returns a hash:
    #  { :box_usage  => string,
    #    :request_id => string,
    #    :attributes => { 'nameA' => [valueA1,..., valueAN],
    #                     ... ,
    #                     'nameZ' => [valueZ1,..., valueZN] } }
    # 
    # Example:
    #  # request all attributes
    #  sdb.get_attributes('family', 'toys') # => { :attributes => {"cat"    => ["clew", "Jons_socks", "mouse"] },
    #                                                              "Silvia" => ["beetle", "rolling_pin", "kids"],
    #                                                              "Jon"    => ["vacuum_cleaner", "hammer", "spade"]},
    #                                              :box_usage  => "0.0000093222",
    #                                              :request_id => "81273d21-000-1111-b3f9-512d91d29ac8" }
    #  
    #  # request cat's attributes only
    #  sdb.get_attributes('family', 'toys', 'cat') # => { :attributes => {"cat" => ["clew", "Jons_socks", "mouse"] },
    #                                                     :box_usage  => "0.0000093222",
    #                                                     :request_id => "81273d21-001-1111-b3f9-512d91d29ac8" }
    #
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API_GetAttributes.html
    #
    def get_attributes(domain_name, item_name, attribute_name=nil)
      link = generate_request("GetAttributes", 'DomainName'    => domain_name,
                                               'ItemName'      => item_name,
                                               'AttributeName' => attribute_name )
      res = request_info(link, QSdbGetAttributesParser.new)
      res[:attributes].each_value do |values|
        values.collect! { |e| sdb_to_ruby(e) }
      end
      res
    rescue Exception
      on_exception
    end

    # Delete value, attribute or item.
    #
    # Example:
    #  # delete 'vodka' and 'girls' from 'Jon' and 'mice' from 'cat'.
    #  sdb.delete_attributes 'family', 'toys', { 'Jon' => ['vodka', 'girls'], 'cat' => ['mice'] }
    #
    #  # delete the all the values from attributes (i.e. delete the attributes)
    #  sdb.delete_attributes 'family', 'toys', { 'Jon' => [], 'cat' => [] }
    #  # or 
    #  sdb.delete_attributes 'family', 'toys', [ 'Jon', 'cat' ]
    #
    #  # delete all the attributes from item 'toys' (i.e. delete the item)
    #  sdb.delete_attributes 'family', 'toys'
    #  
    # see http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API_DeleteAttributes.html 
    #
    def delete_attributes(domain_name, item_name, attributes = nil)
      params = { 'DomainName' => domain_name,
                 'ItemName'   => item_name }.merge(pack_attributes(attributes))
      link = generate_request("DeleteAttributes", params)
      request_info( link, QSdbSimpleParser.new )
    rescue Exception
      on_exception
    end
    
    
    # QUERY:
 
    # Perform a query on SDB.
    # 
    # Returns a hash:
    #   { :box_usage  => string,
    #     :request_id => string,
    #     :next_token => string,
    #     :items      => [ItemName1,..., ItemNameN] }
    #     
    # Example:
    # 
    #   query = "['cat' = 'clew']"
    #   sdb.query('family', query)     #=> hash of data
    #   sdb.query('family', query, 10) #=> hash of data with max of 10 items
    # 
    # If a block is given, query will iteratively yield results to it as long as the block continues to return true.
    # 
    #   # List 10 items per iteration. Don't 
    #   # forget to escape single quotes and backslashes and wrap all the items in single quotes.
    #   query = "['cat'='clew'] union ['dog'='Jon\\'s boot']"
    #   sdb.query('family', query, 10) do |result|
    #     puts result.inspect
    #     true
    #   end
    #  
    #   # Same query using automatic escaping...to use the auto escape, pass the query and its params as an array:
    #   query = [ "['cat'=?] union ['dog'=?]", "clew", "Jon's boot" ]
    #   sdb.query('family', query)
    #
    #   query = [ "['cat'=?] union ['dog'=?] sort 'cat' desc", "clew", "Jon's boot" ]
    #   sdb.query('family', query)
    #
    # see: http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/SDB_API_Query.html
    #      http://docs.amazonwebservices.com/AmazonSimpleDB/2007-11-07/DeveloperGuide/index.html?SortingData.html
    #
    def query(domain_name, query_expression = nil, max_number_of_items = nil, next_token = nil)
      query_expression = query_expression_from_array(query_expression) if query_expression.is_a?(Array)
      @last_query_expression = query_expression
      #
      request_params = { 'DomainName'       => domain_name,
                         'QueryExpression'  => query_expression,
                         'MaxNumberOfItems' => max_number_of_items,
                         'NextToken'        => next_token }
      link   = generate_request("Query", request_params)
      result = request_info( link, QSdbQueryParser.new )
      # return result if no block given
      return result unless block_given?
      # loop if block if given
      begin
        # the block must return true if it wanna continue 
        break unless yield(result) && result[:next_token]
        # make new request
        request_params['NextToken'] = result[:next_token]
        link   = generate_request("Query", request_params)
        result = request_info( link, QSdbQueryParser.new )
      end while true
    rescue Exception
      on_exception
    end
    
    #-----------------------------------------------------------------
    #      PARSERS:
    #-----------------------------------------------------------------
    class QSdbListDomainParser < RightAWSParser #:nodoc:
      def reset
        @result = { :domains => [] }
      end
      def tagend(name)
        case name
        when 'NextToken'  then @result[:next_token] =  @text
        when 'DomainName' then @result[:domains]    << @text
        when 'BoxUsage'   then @result[:box_usage]  =  @text
        when 'RequestId'  then @result[:request_id] =  @text
        end
      end
    end

    class QSdbSimpleParser < RightAWSParser #:nodoc:
      def reset
        @result = {}
      end
      def tagend(name)
        case name
        when 'BoxUsage'  then @result[:box_usage]  =  @text
        when 'RequestId' then @result[:request_id] =  @text
        end
      end
    end

    class QSdbGetAttributesParser < RightAWSParser #:nodoc:
      def reset
        @last_attribute_name = nil
        @result = { :attributes => {} }
      end
      def tagend(name)
        case name
        when 'Name'      then @last_attribute_name = @text
        when 'Value'     then (@result[:attributes][@last_attribute_name] ||= []) << @text
        when 'BoxUsage'  then @result[:box_usage]  =  @text
        when 'RequestId' then @result[:request_id] =  @text
        end
      end
    end

    class QSdbQueryParser < RightAWSParser #:nodoc:
      def reset
        @result = { :items => [] }
      end
      def tagend(name)
        case name
        when 'ItemName'  then @result[:items]      << @text
        when 'BoxUsage'  then @result[:box_usage]  =  @text
        when 'RequestId' then @result[:request_id] =  @text
        when 'NextToken' then @result[:next_token] =  @text
        end
      end
    end

  end
  
end
