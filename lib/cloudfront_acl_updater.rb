# frozen_string_literal: true

class CloudfrontACLUpdater
  IP_SET_NAME_V4 = "RateBasedBlockSetIPv4"
  IP_SET_NAME_V6 = "RateBasedBlockSetIPv6"
  HOUR_LIMIT = 5.gigabytes
  TWELVE_HOUR_LIMIT = 24.gigabytes
  TWENTY_FOUR_HOUR_LIMIT = 48.gigabytes

  PREFIXES_TO_GROUP = CONFIG.cloudfront_ip_prefixes_to_group || []
  PREFIXES_TO_LIMIT = CONFIG.cloudfront_ip_prefixes_to_limit || []

  def initialize
    return unless CONFIG.kibana_es_uri

    aws_config = YAML.load_file( File.join( Rails.root, "config", "s3.yml" ) )
    @aws_client = ::Aws::WAFV2::Client.new(
      access_key_id: aws_config["access_key_id"],
      secret_access_key: aws_config["secret_access_key"],
      region: CONFIG.s3_region
    )
    @ip_set_v4 = get_ip_set_v4
    @ip_set_v6 = get_ip_set_v6
  end

  def update_acl
    return unless @aws_client && @ip_set_v4 && @ip_set_v6

    one_hour_ips = query_for_ips_to_block( 1.hour, CloudfrontACLUpdater::HOUR_LIMIT ) || []
    twelve_hour_ips = query_for_ips_to_block( 12.hour, CloudfrontACLUpdater::TWELVE_HOUR_LIMIT ) || []
    twenty_four_hour_ips = query_for_ips_to_block( 24.hour, CloudfrontACLUpdater::TWENTY_FOUR_HOUR_LIMIT ) || []
    restrict_acl_to_ips( ips: one_hour_ips + twelve_hour_ips + twenty_four_hour_ips )
  end

  private

  def rate_based_ip_set_id( name: )
    return unless @aws_client

    rate_based_ip_set = @aws_client.
      list_ip_sets( scope: "CLOUDFRONT" ).
      ip_sets.detect {| s | s.name == name }
    return unless rate_based_ip_set

    rate_based_ip_set.id
  end

  def get_ip_set( id:, name: )
    return unless @aws_client && id

    @aws_client.get_ip_set( id: id, name: name, scope: "CLOUDFRONT" )
  end

  def get_ip_set_v4
    id = rate_based_ip_set_id( name: IP_SET_NAME_V4 )
    get_ip_set( id: id, name: IP_SET_NAME_V4 )
  end

  def get_ip_set_v6
    id = rate_based_ip_set_id( name: IP_SET_NAME_V6 )
    get_ip_set( id: id, name: IP_SET_NAME_V6 )
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
    return unless kibana_uri&.host && kibana_uri.port

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
    buckets.each do | bucket |
      if bucket["sum_of_bytes"]["value"] >= limit
        ips_over_limit << bucket["key"]
      end
      PREFIXES_TO_GROUP.each do | prefix |
        next unless bucket["key"].starts_with?( prefix )

        prefix_sums[prefix] ||= {}
        prefix_sums[prefix][:sum] ||= 0
        prefix_sums[prefix][:sum] += bucket["sum_of_bytes"]["value"]
        prefix_sums[prefix][:ips] ||= []
        prefix_sums[prefix][:ips] << bucket["key"]
      end
      PREFIXES_TO_LIMIT.each do | prefix |
        if bucket["key"].starts_with?( prefix )
          ips_over_limit << bucket["key"]
        end
      end
    end
    prefix_sums.each_value do | data |
      if data[:sum] >= limit
        ips_over_limit += data[:ips]
      end
    end
    ips_over_limit.uniq
  end

  def update_ip_set( ip_set:, addresses: )
    @aws_client.update_ip_set(
      name: ip_set.ip_set.name,
      scope: "CLOUDFRONT",
      id: ip_set.ip_set.id,
      addresses: addresses,
      lock_token: ip_set.lock_token
    )
    nil
  end

  def restrict_acl_to_ips( ips: )
    return unless @ip_set_v4 && @ip_set_v6

    ips_v4 = []
    ips_v6 = []
    ips.uniq.each do | ip |
      if ip =~ /:/
        ips_v6 << "#{ip}/128"
      else
        ips_v4 << "#{ip}/32"
      end
    end

    update_ip_set( ip_set: @ip_set_v4, addresses: ips_v4 )
    update_ip_set( ip_set: @ip_set_v6, addresses: ips_v6 )
    nil
  end
end
