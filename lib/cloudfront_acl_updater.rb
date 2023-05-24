class CloudfrontACLUpdater
  IP_SET_NAME = "Rate-based Block Set"
  HOUR_LIMIT = 5.gigabytes
  TWELVE_HOUR_LIMIT = 24.gigabytes
  TWENTY_FOUR_HOUR_LIMIT = 48.gigabytes
  attr_reader :aws_client
  attr_reader :ip_set_id

  PREFIXES_TO_GROUP = CONFIG.cloudfront_ip_prefixes_to_group || []
  PREFIXES_TO_LIMIT = CONFIG.cloudfront_ip_prefixes_to_limit || []

  def initialize
    return unless CONFIG.kibana_es_uri
    aws_config = YAML.load_file( File.join( Rails.root, "config", "s3.yml" ) )
    @aws_client = ::Aws::WAF::Client.new(
      access_key_id: aws_config["access_key_id"],
      secret_access_key: aws_config["secret_access_key"],
      region: CONFIG.s3_region
    )
    @ip_set_id = rate_based_ip_set_id
  end

  def update_acl
    return unless @aws_client && @ip_set_id
    one_hour_ips = query_for_ips_to_block( 1.hour, CloudfrontACLUpdater::HOUR_LIMIT ) || []
    twelve_hour_ips = query_for_ips_to_block( 12.hour, CloudfrontACLUpdater::TWELVE_HOUR_LIMIT ) || []
    twenty_four_hour_ips = query_for_ips_to_block( 24.hour, CloudfrontACLUpdater::TWENTY_FOUR_HOUR_LIMIT ) || []
    restrict_acl_to_ips( one_hour_ips + twelve_hour_ips + twenty_four_hour_ips )
  end

  private

  def rate_based_ip_set_id
    return unless @aws_client
    rate_based_ip_set = @aws_client.list_ip_sets.ip_sets.detect{ |s| s.name == IP_SET_NAME }
    return unless rate_based_ip_set
    rate_based_ip_set.ip_set_id
  end

  def fetch_change_token
    return unless @aws_client
    @aws_client.get_change_token.change_token
  end

  def set_descriptors
    return unless @aws_client && @ip_set_id
    ip_set = @aws_client.get_ip_set( ip_set_id: @ip_set_id ).ip_set
    return unless ip_set
    ip_set.ip_set_descriptors
  end

  def prepare_es_query( time_range )
    filters = []
    filters << {
      range: {
        "@timestamp": {
          gte: ( Time.now - time_range ).strftime( "%FT%T%z" ),
          lte: Time.now.strftime( "%FT%T%z" )
        }
      }
    }
    filters << {
      term: {
        type: "cloudfront-logs"
      }
    }
    body = {
      size: 0,
      query: {
        bool: {
          filter: filters
        }
      }
    }
    body[:aggs] = {
      clientips: {
        terms: {
          field: "clientip",
          size: 200,
          order: {
            sum_of_bytes: "desc"
          },
          min_doc_count: 1
        },
        aggs: {
          sum_of_bytes: {
            sum: {
              field: "bytes"
            }
          }
        }
      }
    }
    body
  end

  def query_for_ips_to_block( time_range, limit )
    return unless CONFIG.kibana_es_uri
    kibana_uri = URI.parse( CONFIG.kibana_es_uri )
    return unless kibana_uri && kibana_uri.host && kibana_uri.port
    begin
      http = Net::HTTP.new( kibana_uri.host, kibana_uri.port )
      request = Net::HTTP::Post.new( "/logs-cloudfront-logs-default/_search", "Content-Type": "application/json" )
      request.body = prepare_es_query( time_range ).to_json
      response = http.request( request )
      buckets = JSON.parse( response.body )["aggregations"]["clientips"]["buckets"]
    rescue
      return
    end
    ips_over_limit_from_results( buckets, limit )
  end

  def ips_over_limit_from_results( buckets, limit )
    ips_over_limit = []
    prefix_sums = {}
    buckets.each do |bucket|
      if bucket["sum_of_bytes"]["value"] >= limit
        ips_over_limit << bucket["key"]
      end
      PREFIXES_TO_GROUP.each do |prefix|
        if bucket["key"].starts_with?( prefix )
          prefix_sums[prefix] ||= { }
          prefix_sums[prefix][:sum] ||= 0
          prefix_sums[prefix][:sum] += bucket["sum_of_bytes"]["value"]
          prefix_sums[prefix][:ips] ||= []
          prefix_sums[prefix][:ips] << bucket["key"]
        end
      end
      PREFIXES_TO_LIMIT.each do |prefix|
        if bucket["key"].starts_with?( prefix )
          ips_over_limit << bucket["key"]
        end
      end
    end
    prefix_sums.each do |prefix, data|
      if data[:sum] >= limit
        ips_over_limit += data[:ips]
      end
    end
    ips_over_limit.uniq
  end

  def remove_descriptor( descriptor )
    return unless @aws_client && @ip_set_id
    token = fetch_change_token
    return unless token
    resp = @aws_client.update_ip_set( {
      change_token: token,
      ip_set_id: @ip_set_id,
      updates: [
        {
          action: "DELETE",
          ip_set_descriptor: {
            type: descriptor.type,
            value: descriptor.value,
          }
        }
      ]
    } )
  end

  def add_ip_to_acl( ip )
    return unless @aws_client && @ip_set_id
    token = fetch_change_token
    return unless token
    if ip =~ /:/
      type = "IPV6"
      cidr_suffix = "128"
    else
      type = "IPV4"
      cidr_suffix = "32"
    end
    resp = @aws_client.update_ip_set( {
      change_token: token,
      ip_set_id: @ip_set_id,
      updates: [
        {
          action: "INSERT",
          ip_set_descriptor: {
            type: type,
            value: "#{ip}/#{cidr_suffix}",
          }
        }
      ]
    } )
  end

  def restrict_acl_to_ips( ips )
    already_restricted_ips = []
    existing_rules = set_descriptors
    return unless set_descriptors
    set_descriptors.each do |descriptor|
      rule_ip = descriptor.value.sub( /\/.*$/, "" )
      if ips.include?( rule_ip )
        already_restricted_ips << rule_ip
      else
        remove_descriptor( descriptor )
      end
    end
    ( ips - already_restricted_ips ).each do |ip_to_add|
      add_ip_to_acl( ip_to_add )
    end
  end

end
