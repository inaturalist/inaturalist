# frozen_string_literal: true

NUMBER_OF_DAYS = 30.days
KIBANA_URL = "localhost:9200"

# When run an staging, we don't have data after last friday
# Define the refence as last friday, end of day
current_day_of_week = Time.now.wday
days_to_subtract = ( current_day_of_week - 5 ) % 7
last_friday = ( Time.now - days_to_subtract.days )
at_time = last_friday.utc.end_of_day

# Get all connected users, from database
all_connected_users = User.where( "last_active >= ?", at_time - NUMBER_OF_DAYS ).pluck( :id )

# Get all connected users, who joined recently, from database
new_connected_users = User.where( "last_active >= ?", at_time - NUMBER_OF_DAYS ).
  where( "DATE(created_at AT TIME ZONE 'UTC') >= ?", at_time - NUMBER_OF_DAYS ).pluck( :id )

# Get users having submitted observations
# including the number of observations by application (android, ios, seek, web) for each
def user_obs_data( at_time )
  filter = [
    {
      range: {
        created_at: {
          gte: at_time - NUMBER_OF_DAYS,
          lte: at_time
        }
      }
    }
  ]
  agg = {
    user_id: {
      terms: {
        field: "user.id",
        size: 10_000_000
      },
      aggs: {
        app_id: {
          terms: {
            field: "oauth_application_id",
            size: 10_000_000
          }
        }
      }
    }
  }
  Observation.elastic_search(
    size: 0,
    filters: filter,
    aggregate: agg
  ).response.aggregations.user_id.buckets
end

# Get users having submitted identifications
# including the number of identifications for each
def user_ids_data( at_time )
  filter = [
    {
      range: {
        created_at: {
          gte: at_time - NUMBER_OF_DAYS,
          lte: at_time
        }
      }
    },
    {
      bool: {
        must_not: {
          exists: {
            field: "taxon_change.id"
          }
        }
      }
    }
  ]
  agg = {
    user_id: {
      terms: {
        field: "user.id",
        size: 10_000_000
      },
      aggs: {
        app_id: {
          terms: {
            field: "own_observation",
            size: 10_000_000
          }
        }
      }
    }
  }
  Identification.elastic_search(
    size: 0,
    filters: filter,
    aggregate: agg
  ).response.aggregations.user_id.buckets
end

# Get devices used by users from kibana logs between 2 dates
def users_devices_split_data( start_time, end_time )
  kibana_es_client = Elasticsearch::Client.new(host: KIBANA_URL)
  body = { 
    size: 0,
    query: {
      bool: {
        filter: [
          {
            exists: {
              field: "user_id"
            }
          },
          {
            range: {
              "@timestamp": {
                gte: start_time,
                lt: end_time
              }
            }
          },
          {
            bool: {
              must_not: {
                term: {
                  user_id: -1
                }
              }
            }
          }
        ]
      }
    },
    aggs: {
      user_id: {
        terms: {
          field: "user_id",
          size: 100_000
        },
        aggs: {
          app_id: {
            terms: {
              field: "session.oauth_application_id",
              size: 10_000_000
            }
          }
        }
      }
    }
  }
  begin
    kibana_es_client.search(
      index: 'logs-ruby-logstash-*', 
      body: body)
  rescue Faraday::TimeoutError, Net::ReadTimeout
    retry
  end
end

# Get devices used by users from kibana logs 
# Generate multiple queries (1 by hour of data) to avoid reaching ES max bucket size
def users_devices_data( at_time )
  devices_data = {}
  number_of_days = NUMBER_OF_DAYS / 1.days
  number_of_hours = number_of_days * 24

  total_queries = 0
  for i in 0..(number_of_hours-1)
    start_time = at_time - (number_of_hours - i).hour
    end_time = at_time - (number_of_hours - i - 1).hour
    puts start_time.to_s + " to " + end_time.to_s

    split_data = users_devices_split_data( start_time, end_time )

    split_data["aggregations"]["user_id"]["buckets"].each do | u |
      user = devices_data[u["key"]]
      user ||= {
        total_q_count: 0,
        web_app_q_count: 0,
        ios_app_q_count: 0,
        android_app_q_count: 0,
        seek_app_q_count: 0,
        other_app_q_count: 0
      }
      user[:total_q_count] += u["doc_count"]
      user[:web_app_q_count] += u["doc_count"]
      u["app_id"]["buckets"].each do | a |
        app_q_count = a["doc_count"]
        user[:web_app_q_count] = user[:web_app_q_count] - app_q_count
        case a["key"]
        when 3
          user[:ios_app_q_count] += app_q_count
        when 2
          user[:android_app_q_count] += app_q_count
        when 333
          user[:seek_app_q_count] += app_q_count
        else
          user[:other_app_q_count] += app_q_count
        end
      end
      devices_data[u["key"]] = user
    end

    total_queries = devices_data.values.reduce(0) { |total, item| total + item[:total_q_count] }
    puts "Users = " + devices_data.count.to_s
    puts "Q Count = " + total_queries.to_s
  end

  expected_queries = users_devices_coherency_check( at_time )
  diff_queries = (expected_queries - total_queries) * 100 / expected_queries
  puts "Queries expected = " + expected_queries.to_s
  puts "Queries retrieved = " + total_queries.to_s
  puts "Diff = " + diff_queries.to_s + " %"

  devices_data
end

def users_devices_coherency_check( at_time )
  kibana_es_client = Elasticsearch::Client.new(host: KIBANA_URL)
  body = { 
    size: 0,
    track_total_hits: true,
    query: {
      bool: {
        filter: [
          {
            exists: {
              field: "user_id"
            }
          },
          {
            range: {
              "@timestamp": {
                gte: at_time - NUMBER_OF_DAYS,
                lt: at_time
              }
            }
          },
          {
            bool: {
              must_not: {
                term: {
                  user_id: -1
                }
              }
            }
          }
        ]
      }
    }
  }
  begin
    result = kibana_es_client.search(
      index: 'logs-ruby-logstash-*', 
      body: body)
    result["hits"]["total"]["value"]
  rescue Faraday::TimeoutError, Net::ReadTimeout
    retry
  end
end

# Default user structure
def default_user( user_id )
  {
    id: user_id,
    active: false,
    new: false,
    total_obs_count: 0,
    total_ids_count: 0,
    web_app_obs_count: 0,
    ios_obs_count: 0,
    android_obs_count: 0,
    seek_obs_count: 0,
    other_obs_count: 0,
    own_ids_count: 0,
    other_ids_count: 0,
    total_q_count: 0,
    web_app_q_count: 0,
    ios_app_q_count: 0,
    android_app_q_count: 0,
    seek_app_q_count: 0,
    other_app_q_count: 0
  }
end

# Get data from Elasticsearch
obs_data = user_obs_data( at_time )
ids_data = user_ids_data( at_time )
devices_data = users_devices_data( at_time )

# Initialize the main data structure
user_data = {}

# Process data to get the number of observations by application for each user
obs_data.each do | u |
  user = default_user( u["key"] )
  user[:active] = true
  user[:total_obs_count] = u["doc_count"]
  user[:web_app_obs_count] = u["doc_count"]
  u["app_id"]["buckets"].each do | a |
    app_obs_count = a["doc_count"]
    user[:web_app_obs_count] = user[:web_app_obs_count] - app_obs_count
    case a["key"]
    when 3
      user[:ios_obs_count] = app_obs_count
    when 2
      user[:android_obs_count] = app_obs_count
    when 333
      user[:seek_obs_count] = app_obs_count
    else
      user[:other_obs_count] = app_obs_count
    end
  end
  user_data[u["key"]] = user
end

# Process data to get the number of identifications for each user
ids_data.each do | u |
  user = user_data[u["key"]]
  user ||= default_user( u["key"] )
  user[:active] = true
  user[:total_ids_count] = u["doc_count"]
  u["app_id"]["buckets"].each do | a |
    case a["key"]
    when 0
      user[:other_ids_count] = a["doc_count"]
    when 1
      user[:own_ids_count] = a["doc_count"]
    end
  end
  user_data[u["key"]] = user
end

# Process data to get devices info from inactive users
devices_data.each do | key, u |
  user = user_data[key]
  user ||= default_user( key )
  user[:total_q_count] = u[:total_q_count]
  user[:web_app_q_count] = u[:web_app_q_count]
  user[:ios_app_q_count] = u[:ios_app_q_count]
  user[:android_app_q_count] = u[:android_app_q_count]
  user[:seek_app_q_count] = u[:seek_app_q_count]
  user[:other_app_q_count] = u[:other_app_q_count]
  user_data[key] = user
end

# Process all connected users, to add potentially inactive user
all_connected_users.each do | id |
  user = user_data[id]
  user ||= default_user( id )
  user_data[id] = user
end

# Process all connected users, who joined recently, to add the recent status user
new_connected_users.each do | id |
  user = user_data[id]
  user ||= default_user( id )
  user[:new] = true
  user_data[id] = user
end

# Remove deleted users
deleted_users = DeletedUser.all.pluck( :user_id )
users_to_remove = ( user_data.keys - all_connected_users ) & deleted_users
user_data = user_data.reject {| key, _ | users_to_remove.include? key }

# user_data.select { |key, user| user[:active] == false }.count
# user_data.select { |key, user| user[:active] == true }.count
# user_data.select { |key, user| user[:active] == false && user[:new] == true }.count
# user_data.select { |key, user| user[:active] == true && user[:new] == true }.count
# user_data.select { |key, user| user[:total_obs_count] >= 10 }.count
# user_data.select { |key, user| user[:total_ids_count] >= 10 }.count
# user_data.select { |key, user| (user[:total_obs_count] >= 10 || user[:total_ids_count] >= 10) }.count

# Inactive users
# user_data.select { |key, user| user[:active] == false }.count
# Inactive users
# user_data.select { |key, user| user[:active] == false && user[:total_q_count] > 0 }.count
# Using web only
# user_data.select { |key, user| user[:active] == false && user[:total_q_count] > 0 && user[:web_app_q_count] > 0 && user[:ios_app_q_count] == 0 && user[:android_app_q_count] == 0 && user[:seek_app_q_count] == 0 && user[:other_app_q_count] == 0 }.count
# Using ios only
# user_data.select { |key, user| user[:active] == false && user[:total_q_count] > 0 && user[:web_app_q_count] == 0 && user[:ios_app_q_count] > 0 && user[:android_app_q_count] == 0 && user[:seek_app_q_count] == 0 && user[:other_app_q_count] == 0 }.count
# Using android only
# user_data.select { |key, user| user[:active] == false && user[:total_q_count] > 0 && user[:web_app_q_count] == 0 && user[:ios_app_q_count] == 0 && user[:android_app_q_count] > 0 && user[:seek_app_q_count] == 0 && user[:other_app_q_count] == 0 }.count
# Using seek only
# user_data.select { |key, user| user[:active] == false && user[:total_q_count] > 0 && user[:web_app_q_count] == 0 && user[:ios_app_q_count] == 0 && user[:android_app_q_count] == 0 && user[:seek_app_q_count] > 0 && user[:other_app_q_count] == 0 }.count
