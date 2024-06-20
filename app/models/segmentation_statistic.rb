# frozen_string_literal: true

class SegmentationStatistic < ApplicationRecord
  def self.generate_stats_for_day( at_time = Time.now, options = {} )
    at_time = at_time.utc.end_of_day
    if options[:force]
      SegmentationStatistic.where( "DATE(created_at) = DATE(?)", at_time.utc ).delete_all
    elsif stats_generated_for_day?( at_time )
      return
    end
    sleep 1
    SegmentationStatistic.create!(
      data: generate_segmentation_metrics( at_time ),
      created_at: at_time.beginning_of_day
    )
  end

  def self.stats_generated_for_day?( at_time = Time.now )
    SegmentationStatistic.where( "DATE(created_at) = DATE(?)", at_time.utc ).exists?
  end

  def self.generate_segmentation_data_for_interval( start_date, end_date, use_database: false )
    segmentation_data = {}
    current_date = end_date
    num_days = ( end_date.to_date - start_date.to_date ).to_i
    num_days.times do
      puts "Processing #{current_date}..."
      users_from_kibana_data( current_date, segmentation_data )
      current_date -= 1.day
    end
    users_from_db( end_date, segmentation_data ) if use_database
    segmentation_data
  end

  # private

  NUMBER_OF_DAYS = 30

  # Generate metrics
  def self.generate_segmentation_metrics( at_time = Time.now )
    segmentation_data = generate_segmentation_data( at_time )
    dau_mau_kibana_data = generate_dau_mau_kibana_data( at_time )
    {
      main_metrics: generate_main_metrics( segmentation_data ),
      dau_mau_metrics: generate_dau_mau_metrics( segmentation_data, dau_mau_kibana_data )
    }
  end

  # Generate all the users data
  def self.generate_segmentation_data( at_time = Time.now )
    segmentation_data = {}
    day = at_time
    NUMBER_OF_DAYS.times do
      users_from_obs_data( day, segmentation_data )
      users_from_ids_data( day, segmentation_data )
      users_from_kibana_data( day, segmentation_data )
      day -= 1.days
    end
    users_from_db( at_time, segmentation_data )
    segmentation_data
  end

  # Default user structure
  def self.default_user( user_id )
    {
      id: user_id,
      active: false,
      new: false,
      created_at: -1,
      total_obs: 0,
      total_ids: 0,
      obs: 0,
      ids: 0,
      web_obs: 0,
      ios_obs: 0,
      android_obs: 0,
      seek_obs: 0,
      other_obs: 0,
      q: 0,
      web_q: 0,
      ios_q: 0,
      android_q: 0,
      seek_q: 0,
      other_q: 0
    }
  end

  # Get users having submitted observations
  # including the number of observations by application (android, ios, seek, web) for each
  def self.users_from_obs_data( day, users_data )
    filter = [
      {
        range: {
          created_at: {
            gte: day.beginning_of_day,
            lte: day.end_of_day
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

    obs_data = Observation.elastic_search(
      size: 0,
      filters: filter,
      aggregate: agg
    ).response.aggregations.user_id.buckets

    obs_data.each do | user_counts_bucket |
      user = users_data[user_counts_bucket["key"]]
      user ||= default_user( user_counts_bucket["key"] )
      user[:active] = true
      user[:obs] += user_counts_bucket["doc_count"]
      user[:web_obs] += user_counts_bucket["doc_count"]
      user_counts_bucket["app_id"]["buckets"].each do | user_app_bucket |
        app_obs_count = user_app_bucket["doc_count"]
        user[:web_obs] -= app_obs_count
        case user_app_bucket["key"]
        when OauthApplication.inaturalist_iphone_app&.id
          user[:ios_obs] += app_obs_count
        when OauthApplication.inaturalist_android_app&.id
          user[:android_obs] += app_obs_count
        when OauthApplication.seek_app&.id
          user[:seek_obs] += app_obs_count
        else
          user[:other_obs] += app_obs_count
        end
      end
      users_data[user_counts_bucket["key"]] = user
    end
  end

  # Get users having submitted identifications
  # including the number of identifications for each
  def self.users_from_ids_data( day, users_data )
    filter = [
      {
        range: {
          created_at: {
            gte: day.beginning_of_day,
            lte: day.end_of_day
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
      },
      {
        bool: {
          must: {
            term: {
              own_observation: false
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
        }
      }
    }

    ids_data = Identification.elastic_search(
      size: 0,
      filters: filter,
      aggregate: agg
    ).response.aggregations.user_id.buckets

    ids_data.each do | user_counts_bucket |
      user = users_data[user_counts_bucket["key"]]
      user ||= default_user( user_counts_bucket["key"] )
      user[:active] = true
      user[:ids] += user_counts_bucket["doc_count"]
      users_data[user_counts_bucket["key"]] = user
    end
  end

  # From kibana logs:
  # - Get devices used by users
  # - Get number of users connected per day
  # Generate multiple queries (1 by hour of data) to avoid reaching ES max bucket size
  def self.users_from_kibana_data( day, users_data )
    kibana_es_client = Elasticsearch::Client.new( host: CONFIG.kibana_es_uri )

    start_time = day.beginning_of_day
    24.times.each do
      end_time = start_time + 1.hour

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
        kibana_data = kibana_es_client.search(
          index: "logs-ruby-logstash-*",
          body: body
        )
      rescue Faraday::TimeoutError, Net::ReadTimeout
        retry
      end

      kibana_data["aggregations"]["user_id"]["buckets"].each do | user_counts_bucket |
        user = users_data[user_counts_bucket["key"]]
        user ||= default_user( user_counts_bucket["key"] )
        user[:q] += user_counts_bucket["doc_count"]
        user[:web_q] += user_counts_bucket["doc_count"]
        user_counts_bucket["app_id"]["buckets"].each do | user_app_bucket |
          app_q_count = user_app_bucket["doc_count"]
          user[:web_q] -= app_q_count
          case user_app_bucket["key"]
          when OauthApplication.inaturalist_iphone_app&.id
            user[:ios_q] += app_q_count
          when OauthApplication.inaturalist_android_app&.id
            user[:android_q] += app_q_count
          when OauthApplication.seek_app&.id
            user[:seek_q] += app_q_count
          else
            user[:other_q] += app_q_count
          end
        end
        users_data[user_counts_bucket["key"]] = user
      end

      start_time = end_time
    end
  end

  # From the database
  # Calculate the number of days since account creation
  # Flag as new if <= 30 days
  # Get also current observations_count and identifications_count
  def self.users_from_db( day, users_data )
    users_data.keys.each_slice( 1000 ) do | batch_ids |
      User.where( id: batch_ids ).pluck( :id, :created_at, :observations_count, :identifications_count ).
        each do | user_from_db |
        id = user_from_db[0]
        created_at = user_from_db[1]
        observations_count = user_from_db[2]
        identifications_count = user_from_db[3]
        user_data = users_data[id]
        next if user_data.nil?

        user_data[:total_obs] = observations_count
        user_data[:total_ids] = identifications_count
        next if created_at.nil?

        days_since_creation = ( day.to_date - created_at.to_date ).to_i
        days_since_creation = 0 if days_since_creation.negative?
        user_data[:created_at] = days_since_creation
        if days_since_creation <= 30
          user_data[:new] = true
        end
      end
    end
  end

  #
  # Metrics aggregated by
  # - new / existing users (created_at)
  # - power / casual / inactive users
  # - devices
  #     used to post observations for power/casual observers
  #     used to query our servers for others (iders or inactive)
  #

  # Type = web, ios, android, seek, other
  # Subtype = obs or q
  def self.count_most_used_device( sub_data, type, sub_type )
    sub_data.select do | _, user |
      case type
      when "web"
        user[:"#{type}_#{sub_type}"] >= [user[:"ios_#{sub_type}"],
                                         user[:"android_#{sub_type}"],
                                         user[:"seek_#{sub_type}"],
                                         user[:"other_#{sub_type}"]].max
      when "ios"
        user[:"#{type}_#{sub_type}"] > user[:"web_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] >= [user[:"android_#{sub_type}"],
                                           user[:"seek_#{sub_type}"],
                                           user[:"other_#{sub_type}"]].max
      when "android"
        user[:"#{type}_#{sub_type}"] > user[:"web_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] > user[:"ios_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] >= [user[:"seek_#{sub_type}"],
                                           user[:"other_#{sub_type}"]].max
      when "seek"
        user[:"#{type}_#{sub_type}"] > user[:"web_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] > user[:"ios_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] > user[:"android_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] >= user[:"other_#{sub_type}"]
      when "other"
        user[:"#{type}_#{sub_type}"] > user[:"web_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] > user[:"ios_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] > user[:"android_#{sub_type}"] &&
          user[:"#{type}_#{sub_type}"] > user[:"seek_#{sub_type}"]
      end
    end.count
  end

  def self.generate_main_sub_metrics( sub_data )
    is_active_condition = ->( user ) { user[:active] }
    is_power_obs_condition = ->( user ) { user[:obs] >= 10 }
    is_casual_obs_condition = ->( user ) { user[:obs].positive? && user[:obs] < 10 }
    is_power_ids_condition = ->( user ) { user[:ids] >= 10 && user[:obs].zero? }
    is_casual_ids_condition = ->( user ) { user[:ids].positive? && user[:ids] < 10 && user[:obs].zero? }
    {
      total: sub_data.size,
      power_obs: {
        total: sub_data.select {| _, user | is_power_obs_condition.call( user ) }.count,
        web: count_most_used_device(
          sub_data.select {| _, user | is_power_obs_condition.call( user ) }, "web", "obs"
        ),
        ios: count_most_used_device(
          sub_data.select {| _, user | is_power_obs_condition.call( user ) }, "ios", "obs"
        ),
        android: count_most_used_device(
          sub_data.select {| _, user | is_power_obs_condition.call( user ) }, "android", "obs"
        ),
        seek: count_most_used_device(
          sub_data.select {| _, user | is_power_obs_condition.call( user ) }, "seek", "obs"
        ),
        other: count_most_used_device(
          sub_data.select {| _, user | is_power_obs_condition.call( user ) }, "other", "obs"
        )
      },
      power_ids: {
        total: sub_data.select {| _, user | is_power_ids_condition.call( user ) }.count
      },
      casual_obs: {
        total: sub_data.select {| _, user | is_casual_obs_condition.call( user ) }.count,
        web: count_most_used_device(
          sub_data.select {| _, user | is_casual_obs_condition.call( user ) }, "web", "obs"
        ),
        ios: count_most_used_device(
          sub_data.select {| _, user | is_casual_obs_condition.call( user ) }, "ios", "obs"
        ),
        android: count_most_used_device(
          sub_data.select {| _, user | is_casual_obs_condition.call( user ) }, "android", "obs"
        ),
        seek: count_most_used_device(
          sub_data.select {| _, user | is_casual_obs_condition.call( user ) }, "seek", "obs"
        ),
        other: count_most_used_device(
          sub_data.select {| _, user | is_casual_obs_condition.call( user ) }, "other", "obs"
        )
      },
      casual_ids: {
        total: sub_data.select {| _, user | is_casual_ids_condition.call( user ) }.count
      },
      inactive: {
        total: sub_data.reject {| _, user | is_active_condition.call( user ) }.count,
        web: count_most_used_device(
          sub_data.reject {| _, user | is_active_condition.call( user ) }, "web", "q"
        ),
        ios: count_most_used_device(
          sub_data.reject {| _, user | is_active_condition.call( user ) }, "ios", "q"
        ),
        android: count_most_used_device(
          sub_data.reject {| _, user | is_active_condition.call( user ) }, "android", "q"
        ),
        seek: count_most_used_device(
          sub_data.reject {| _, user | is_active_condition.call( user ) }, "seek", "q"
        ),
        other: count_most_used_device(
          sub_data.reject {| _, user | is_active_condition.call( user ) }, "other", "q"
        )
      }
    }
  end

  def self.generate_main_metrics( segmentation_data )
    is_new_condition = ->( user ) { user[:new] }
    metrics = {}
    metrics[:all] = generate_main_sub_metrics( segmentation_data )
    metrics[:new] = generate_main_sub_metrics(
      segmentation_data.select {| _, user | is_new_condition.call( user ) }
    )
    metrics[:existing] = generate_main_sub_metrics(
      segmentation_data.reject {| _, user | is_new_condition.call( user ) }
    )
    metrics
  end

  #
  # DAU/MAU Metrics
  #

  # Generate all the daily kibana data for DAU/MAU
  def self.generate_dau_mau_kibana_data( at_time = Time.now )
    dau_mau_kibana_data = []
    day = at_time
    ( 1..NUMBER_OF_DAYS ).each do | day_id |
      daily_segmentation_data = {}
      users_from_kibana_data( day, daily_segmentation_data )
      dau_mau_kibana_data[day_id - 1] = daily_segmentation_data
      day -= 1.days
    end
    dau_mau_kibana_data
  end

  def self.calculate_dau_mau( users_from_bucket, dau_mau_kibana_data, label )
    # mau
    mau = users_from_bucket.size
    # dau
    daily_users_from_bucket_count = 0
    dau_mau_kibana_data.each do | daily_kibana_data |
      daily_users_from_bucket_count +=
        daily_kibana_data.select {| key, _ | users_from_bucket.key?( key ) }.count
    end
    dau = daily_users_from_bucket_count / dau_mau_kibana_data.size
    # dau/mau
    dau_mau = 100 * dau.to_f / mau
    {
      label: label,
      dau: dau,
      mau: mau,
      dau_mau: dau_mau
    }
  end

  def self.generate_dau_mau_metrics( segmentation_data, dau_mau_kibana_data )
    {
      all_users: calculate_dau_mau(
        segmentation_data,
        dau_mau_kibana_data,
        "All Users"
      ),
      power_users: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:obs] >= 10 },
        dau_mau_kibana_data,
        "Power Users"
      ),
      casual_users: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:obs].positive? && user[:obs] < 10 },
        dau_mau_kibana_data,
        "Casual Users"
      ),
      inactive_users: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:active] == false },
        dau_mau_kibana_data,
        "Inactive Users"
      ),
      new_account: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] >= 0 && user[:created_at] <= 30 },
        dau_mau_kibana_data,
        "New account"
      ),
      existing_account: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 30 },
        dau_mau_kibana_data,
        "Existing account"
      ),
      created_at_0d_30d: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] >= 0 && user[:created_at] <= 30 },
        dau_mau_kibana_data,
        "Before 30 days"
      ),
      created_at_30d_3m: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 30 && user[:created_at] <= 90 },
        dau_mau_kibana_data,
        "From 30 days to 3 months"
      ),
      created_at_3m_6m: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 90 && user[:created_at] <= 180 },
        dau_mau_kibana_data,
        "From 3 months to 6 months"
      ),
      created_at_6m_1y: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 180 && user[:created_at] <= 365 },
        dau_mau_kibana_data,
        "From 6 months to 1 year"
      ),
      created_at_1y_2y: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 365 && user[:created_at] <= 730 },
        dau_mau_kibana_data,
        "From 1 year to 2 years"
      ),
      created_at_2y_3y: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 730 && user[:created_at] <= 1095 },
        dau_mau_kibana_data,
        "From 2 years to 3 years"
      ),
      created_at_3y_4y: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 1095 && user[:created_at] <= 1460 },
        dau_mau_kibana_data,
        "From 3 years to 4 years"
      ),
      created_at_4y_5y: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 1460 && user[:created_at] <= 1825 },
        dau_mau_kibana_data,
        "From 4 years to 5 years"
      ),
      created_at_5y_10y: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 1825 && user[:created_at] <= 3650 },
        dau_mau_kibana_data,
        "From 5 years to 10 years"
      ),
      created_at_over_10y: calculate_dau_mau(
        segmentation_data.select {| _, user | user[:created_at] > 3650 },
        dau_mau_kibana_data,
        "After 10 years"
      )
    }
  end

  #
  # Daily Active User Model Metrics
  #

  # Generate the daily active user model data
  def self.generate_daily_active_user_model_data( start_date, end_date, use_database: false )
    segmentation_data = {}
    current_date = end_date
    num_days = ( end_date.to_date - start_date.to_date ).to_i
    num_days.times do
      users_from_kibana_data( current_date, segmentation_data )
      current_date -= 1.day
    end
    users_from_db( end_date, segmentation_data ) if use_database
    segmentation_data
  end
end
