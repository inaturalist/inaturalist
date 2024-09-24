# frozen_string_literal: true

require "rubygems"
require "optimist"
require "csv"

OPTS = Optimist.options do
  banner <<~HELP
    Usage:

      rails runner tools/export_user_logs.rb

    where [options] are:
  HELP
  opt :user_id, "user-id", type: :integer, short: "-u"
  opt :end_date, "end-date", type: :string, short: "-d"
end

user = User.find_by_id( OPTS.user_id )
end_date = Date.parse( OPTS.end_date ).end_of_day

puts "Exporting logs for #{user.id} / #{user.login} until #{end_date}"

observations = user.observations.pluck( :id )
observations_from_comments = ( user.comments.where( parent_type: "Observation" ).pluck( :parent_id ) - observations )
observations_from_identifications = ( user.identifications.pluck( :observation_id ) - observations )
observations_from_annotations = (
  user.annotations.where( resource_type: "Observation" ).pluck( :resource_id ) - observations
)

def write_csv( logs, file )
  CSV.open( file, "wb", force_quotes: true ) do | csv |
    csv << ["status_code", "user_id", "user_name", "path", "clientip", "geoip_country_name",
            "geoip_city_name", "geoip_region_name", "method", "ip", "timestamp",
            "HTTP_X_FORWARDED_FOR", "HTTP_X_COUNTRY_CODE", "HTTP_HOST", "bot", "parsed_user_agent_original"]

    logs.each do | log |
      csv << [
        log[:status_code], log[:user_id], log[:user_name], log[:path], log[:clientip],
        log[:geoip_country_name], log[:geoip_city_name], log[:geoip_region_name],
        log[:method], log[:ip], log[:timestamp], log[:HTTP_X_FORWARDED_FOR],
        log[:HTTP_X_COUNTRY_CODE], log[:HTTP_HOST], log[:bot], log[:parsed_user_agent_original]
      ]
    end
  end
end

def process_log( log, is_ruby )
  source = log["_source"]
  return {} unless source

  {
    status_code: source["status_code"],
    user_id: source["user_id"],
    user_name: is_ruby ? source["user_name"] : "",
    path: is_ruby ? source["path"] : source["url"],
    clientip: source["clientip"],
    geoip_country_name: source.dig( "geoip", "country_name" ),
    geoip_city_name: source.dig( "geoip", "city_name" ),
    geoip_region_name: source.dig( "geoip", "region_name" ),
    method: source["method"],
    ip: source["ip"],
    timestamp: source["@timestamp"],
    HTTP_X_FORWARDED_FOR: is_ruby ? source["HTTP_X_FORWARDED_FOR"] : source["x_forwarded_for"],
    HTTP_X_COUNTRY_CODE: is_ruby ? source["HTTP_X_COUNTRY_CODE"] : source["x_country_code"],
    HTTP_HOST: is_ruby ? source["HTTP_HOST"] : source["http_host"],
    bot: source["bot"],
    parsed_user_agent_original: source.dig( "parsed_user_agent", "original" )
  }
end

def fetch_logs( client, index, body, logs_data, is_ruby, scroll_timeout: "1m", scroll_size: 1000 )
  # Initial search request
  response = client.search(
    index: index,
    body: body,
    scroll: scroll_timeout,
    size: scroll_size
  )

  # Process the first batch
  scroll_id = response["_scroll_id"]
  hits = response["hits"]["hits"]
  logs_data.concat( hits.map {| log | process_log( log, is_ruby ) } )

  # Continue scrolling until no more hits
  while hits.any?
    response = client.scroll(
      body: { scroll_id: scroll_id },
      scroll: scroll_timeout
    )

    scroll_id = response["_scroll_id"]
    hits = response["hits"]["hits"]
    logs_data.concat( hits.map {| log | process_log( log, is_ruby ) } )
  end

  # Clear scroll context to free resources
  client.clear_scroll( body: { scroll_id: scroll_id } ) if scroll_id
end

def extract_others_ruby_observations_logs_from_kibana( ids, end_date )
  kibana_es_client = Elasticsearch::Client.new( host: CONFIG.kibana_es_uri )
  logs_data = []
  ids.each_slice( 1000 ) do | batch_ids |
    paths = batch_ids.map {| id | "/observations/#{id}" }
    body = {
      query: {
        bool: {
          must: [
            {
              terms: {
                path: paths
              }
            }
          ],
          filter: [
            {
              range: {
                "@timestamp": {
                  lt: end_date
                }
              }
            }
          ]
        }
      }
    }
    fetch_logs( kibana_es_client, "logs-ruby-*", body, logs_data, true )
  end
  logs_data
end

def profile_paths( id )
  [
    "/users/#{id}",
    "/people/#{id}",
    "/observations?place_id=any&user_id=#{id}&verifiable=any",
    "/calendar/#{id}",
    "/identifications/#{id}",
    "/lists/#{id}",
    "/journal/#{id}",
    "/faves/#{id}",
    "/projects/user/#{id}",
    "/lifelists/#{id}",
    "/observations?annotation_user_id=#{id}&place_id=any&verifiable=any",
    "/people/#{id}/followers"
  ]
end

def extract_others_ruby_profile_logs_from_kibana( user_id, user_name, end_date )
  kibana_es_client = Elasticsearch::Client.new( host: CONFIG.kibana_es_uri )
  logs_data = []
  body = {
    query: {
      bool: {
        must: [
          {
            terms: {
              path: profile_paths( user_id ) + profile_paths( user_name )
            }
          }
        ],
        filter: [
          {
            range: {
              "@timestamp": {
                lt: end_date
              }
            }
          }
        ]
      }
    }
  }
  fetch_logs( kibana_es_client, "logs-ruby-*", body, logs_data, true )
  logs_data
end

def extract_user_ruby_logs_from_kibana( user_id, end_date )
  kibana_es_client = Elasticsearch::Client.new( host: CONFIG.kibana_es_uri )
  logs_data = []
  body = {
    query: {
      bool: {
        must: [
          {
            term: {
              user_id: user_id
            }
          }
        ],
        filter: [
          {
            range: {
              "@timestamp": {
                lt: end_date
              }
            }
          }
        ]
      }
    }
  }
  fetch_logs( kibana_es_client, "logs-ruby-*", body, logs_data, true )
  logs_data
end

def extract_others_node_logs_from_kibana( ids, end_date )
  kibana_es_client = Elasticsearch::Client.new( host: CONFIG.kibana_es_uri )
  logs_data = []
  ids.each_slice( 1000 ) do | batch_ids |
    body = {
      query: {
        bool: {
          must: [
            {
              terms: {
                route: ["/v1/observations/:id", "/v2/observations/:id"]
              }
            },
            {
              terms: {
                "params.id": batch_ids
              }
            }
          ],
          filter: [
            {
              range: {
                "@timestamp": {
                  lt: end_date
                }
              }
            }
          ]
        }
      }
    }
    fetch_logs( kibana_es_client, "logs-node-*", body, logs_data, false )
  end
  logs_data
end

def extract_user_node_logs_from_kibana( user_id, end_date )
  kibana_es_client = Elasticsearch::Client.new( host: CONFIG.kibana_es_uri )
  logs_data = []
  body = {
    query: {
      bool: {
        must: [
          {
            term: {
              user_id: user_id
            }
          }
        ],
        filter: [
          {
            range: {
              "@timestamp": {
                lt: end_date
              }
            }
          }
        ]
      }
    }
  }
  fetch_logs( kibana_es_client, "logs-node-*", body, logs_data, false )
  logs_data
end

puts "Exporting ruby logs from observations..."
ruby_logs_from_observations = extract_others_ruby_observations_logs_from_kibana( observations, end_date )

puts "Exporting ruby logs from comments..."
ruby_logs_from_comments = extract_others_ruby_observations_logs_from_kibana( observations_from_comments, end_date )

puts "Exporting ruby logs from identifications..."
ruby_logs_from_identifications = extract_others_ruby_observations_logs_from_kibana(
  observations_from_identifications, end_date
)

puts "Exporting ruby logs from annotations..."
ruby_logs_from_annotations = extract_others_ruby_observations_logs_from_kibana(
  observations_from_annotations, end_date
)

puts "Exporting ruby logs from profile..."
ruby_logs_from_profile = extract_others_ruby_profile_logs_from_kibana( user.id, user.login, end_date )

puts "Exporting ruby user logs..."
ruby_logs_from_user = extract_user_ruby_logs_from_kibana( user.id, end_date )

puts "Exporting node logs from observations..."
node_logs_from_observations = extract_others_node_logs_from_kibana( observations, end_date )

puts "Exporting node logs from comments..."
node_logs_from_comments = extract_others_node_logs_from_kibana( observations_from_comments, end_date )

puts "Exporting node logs from identifications..."
node_logs_from_identifications = extract_others_node_logs_from_kibana( observations_from_identifications, end_date )

puts "Exporting node logs from annotations..."
node_logs_from_annotations = extract_others_node_logs_from_kibana( observations_from_annotations, end_date )

puts "Exporting node user logs..."
node_logs_from_user = extract_user_node_logs_from_kibana( user.id, end_date )

suffix = "#{Date.today.to_s.gsub( /\-/, '' )}-#{Time.now.to_i}"

puts "Writing CSV files #{suffix}..."
write_csv( ruby_logs_from_observations, "export-user-#{user.id}-obs-ruby-logs-" + suffix )
write_csv( ruby_logs_from_comments, "export-user-#{user.id}-comments-ruby-logs-" + suffix )
write_csv( ruby_logs_from_identifications, "export-user-#{user.id}-ids-ruby-logs-" + suffix )
write_csv( ruby_logs_from_annotations, "export-user-#{user.id}-annotations-ruby-logs-" + suffix )
write_csv( ruby_logs_from_profile, "export-user-#{user.id}-profile-ruby-logs-" + suffix )
write_csv( ruby_logs_from_user, "export-user-#{user.id}-user-ruby-logs-" + suffix )

write_csv( node_logs_from_observations, "export-user-#{user.id}-obs-node-logs-" + suffix )
write_csv( node_logs_from_comments, "export-user-#{user.id}-comments-node-logs-" + suffix )
write_csv( node_logs_from_identifications, "export-user-#{user.id}-ids-node-logs-" + suffix )
write_csv( node_logs_from_annotations, "export-user-#{user.id}-annotations-node-logs-" + suffix )
write_csv( node_logs_from_user, "export-user-#{user.id}-user-node-logs-" + suffix )
