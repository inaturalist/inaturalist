# frozen_string_literal: true

class UserInstallationStatistic < ApplicationRecord
  def self.update_today_installation_ids( at_time = Time.now )
    installation_data = {}
    get_installation_activity_from_kibana_data( at_time, "iNaturalistAndroid", "Android", installation_data )
    get_installation_activity_from_kibana_data( at_time, "iNaturalistiOS", "iOS", installation_data )
    get_installation_activity_from_kibana_data( at_time, "iNaturalistReactNative", "Android", installation_data )
    get_installation_activity_from_kibana_data( at_time, "iNaturalistReactNative", "iOS", installation_data )
    installation_data.keys.in_groups_of( 1000, false ).each do | installation_ids |
      User.transaction do
        existing_records = UserInstallation.where( installation_id: installation_ids )
        unrecorded_ids = installation_ids - existing_records.map( &:installation_id )
        # Create new user installations
        new_records = unrecorded_ids.map do | installation_id |
          installation_from_kibana = installation_data[installation_id]
          if installation_from_kibana[:user_id].nil?
            UserInstallation.new(
              installation_id: installation_id,
              oauth_application_id: installation_from_kibana[:oauth_application_id],
              platform_id: installation_from_kibana[:platform_id],
              created_at: at_time
            )
          else
            UserInstallation.new(
              installation_id: installation_id,
              oauth_application_id: installation_from_kibana[:oauth_application_id],
              platform_id: installation_from_kibana[:platform_id],
              created_at: at_time,
              user_id: installation_from_kibana[:user_id],
              first_logged_in_at: at_time
            )
          end
        end
        # Update user of installations if needed, but keep the first logged in date
        ( existing_records + new_records ).each do | installation_from_db |
          installation_from_kibana = installation_data[installation_from_db.installation_id]
          if installation_from_db.user_id != installation_from_kibana[:user_id]
            installation_from_db.first_logged_in_at = at_time if installation_from_db.user_id.nil?
            installation_from_db.user_id = installation_from_kibana[:user_id]
          end
          next unless installation_from_db.changed?

          installation_from_db.save!
        end
      end
    end
  end

  def self.calculate_all_retention_metrics( at_time = Time.now )
    {
      iNaturalistAndroid: calculate_retention_metrics( at_time, "iNaturalistAndroid", "Android" ),
      iNaturalistiOS: calculate_retention_metrics( at_time, "iNaturalistiOS", "iOS" ),
      iNaturalistReactNativeAndroid: calculate_retention_metrics( at_time, "iNaturalistReactNative", "Android" ),
      iNaturalistReactNativeiOS: calculate_retention_metrics( at_time, "iNaturalistReactNative", "iOS" )
    }
  end

  # private

  # Default user structure
  def self.default_installation( installation_id )
    {
      installation_id: installation_id,
      oauth_application_id: 0,
      platform_id: "",
      user_id: 0
    }
  end

  # From kibana logs:
  # - For a defined application id
  # - Get installation id
  # - Get associated user id if available
  # Generate multiple queries (1 by hour of data) to avoid reaching ES max bucket size
  def self.get_installation_activity_from_kibana_data( day, application_id, platform_id, installation_activity_data )
    kibana_es_client = Elasticsearch::Client.new( host: CONFIG.kibana_es_uri )
    puts "installation activity_from_kibana_data = #{day} / #{application_id}"
    oauth_application_id = convert_application_id_into_oauth_application_id( application_id )
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
                  field: "x_installation_id"
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
                  must: [
                    { term: { "parsed_user_agent.name": application_id } },
                    { term: { "parsed_user_agent.os.name": platform_id } }
                  ]
                }
              }
            ]
          }
        },
        aggs: {
          composite_agg: {
            composite: {
              sources: [
                {
                  x_installation_id: { terms: { field: "x_installation_id" } }
                },
                {
                  user_id: { terms: { field: "user_id", missing_bucket: true } }
                }
              ]
            }
          }
        }
      }
      begin
        kibana_data = kibana_es_client.search(
          index: "logs-node-logstash-*",
          body: body
        )
      rescue Faraday::TimeoutError, Net::ReadTimeout
        retry
      end

      kibana_data["aggregations"]["composite_agg"]["buckets"].each do | bucket |
        installation_id = bucket["key"]["x_installation_id"]
        installation = installation_activity_data[installation_id]
        installation ||= default_installation( installation_id )
        installation[:oauth_application_id] = oauth_application_id
        installation[:platform_id] = platform_id
        installation[:user_id] = bucket["key"]["user_id"]
        installation_activity_data[installation_id] = installation
      end

      start_time = end_time
    end
  end

  def self.get_installation_activity_data( start_date, end_date, application_id, platform_id )
    installation_activity_data = {}
    current_date = end_date
    num_days = ( end_date.to_date - start_date.to_date ).to_i
    num_days.times do
      get_installation_activity_from_kibana_data(
        current_date,
        application_id,
        platform_id,
        installation_activity_data
      )
      current_date -= 1.day
    end
    installation_activity_data
  end

  def self.get_installation_creation_data( creation_date, application_id, platform_id )
    UserInstallation.where(
      "created_at=? AND oauth_application_id=? AND platform_id=?",
      creation_date,
      convert_application_id_into_oauth_application_id( application_id ),
      platform_id
    )
  end

  def self.convert_application_id_into_oauth_application_id( application_id )
    case application_id
    when "iNaturalistAndroid"
      OauthApplication.inaturalist_android_app&.id
    when "iNaturalistiOS"
      OauthApplication.inaturalist_iphone_app&.id
    when "iNaturalistReactNative"
      OauthApplication.inat_next_app&.id
    else
      0
    end
  end

  def self.calculate_retention_metrics( at_time = Time.now, application_id, platform_id )
    day_0 = at_time.utc.end_of_day - 1.day

    today_installation_activity_data = get_installation_activity_data(
      day_0 - 1.day,
      day_0,
      application_id,
      platform_id
    )
    this_week_installation_activity_data = get_installation_activity_data(
      day_0 - 8.days,
      day_0,
      application_id,
      platform_id
    )

    today_minus_7_installation_creation_data = get_installation_creation_data(
      day_0 - 7.days,
      application_id,
      platform_id
    )
    today_minus_14_installation_creation_data = get_installation_creation_data(
      day_0 - 14.days,
      application_id,
      platform_id
    )
    today_minus_28_installation_creation_data = get_installation_creation_data(
      day_0 - 28.days,
      application_id,
      platform_id
    )

    today_active_installations = today_installation_activity_data.count
    this_week_active_installations = this_week_installation_activity_data.count

    today_minus_7_created_installations = today_minus_7_installation_creation_data.count
    today_minus_14_created_installations = today_minus_14_installation_creation_data.count
    today_minus_28_created_installations = today_minus_28_installation_creation_data.count

    today_installation_ids = today_installation_activity_data.values.map {| data | data[:installation_id] }
    this_week_installation_ids = this_week_installation_activity_data.values.map {| data | data[:installation_id] }

    # 7 day retention
    # users that installed the app on day "today-7"
    # and connected today
    retention_7_day_installation_data = today_minus_7_installation_creation_data.select do | user_installation |
      today_installation_ids.include?( user_installation.installation_id )
    end
    today_minus_7_created_installations_active_today = retention_7_day_installation_data.count
    retention_7_day = if today_minus_7_created_installations.zero?
      nil
    else
      100 * today_minus_7_created_installations_active_today.to_f / today_minus_7_created_installations
    end

    # 14 day retention:
    # users that installed the app on day "today-14"
    # and connected today
    retention_14_day_installation_data = today_minus_14_installation_creation_data.select do | user_installation |
      today_installation_ids.include?( user_installation.installation_id )
    end
    today_minus_14_created_installations_active_today = retention_14_day_installation_data.count
    retention_14_day = if today_minus_14_created_installations.zero?
      nil
    else
      100 * today_minus_14_created_installations_active_today.to_f / today_minus_14_created_installations
    end

    # 28 day retention:
    # users that installed the app on day "today-28"
    # and connected today
    retention_28_day_installation_data = today_minus_28_installation_creation_data.select do | user_installation |
      today_installation_ids.include?( user_installation.installation_id )
    end
    today_minus_28_created_installations_active_today = retention_28_day_installation_data.count
    retention_28_day = if today_minus_28_created_installations.zero?
      nil
    else
      100 * today_minus_28_created_installations_active_today.to_f / today_minus_28_created_installations
    end

    # 1 week retention:
    # users that installed the app on day "today-7"
    # and connected at least once between today-7 and today
    retention_1_week_installation_data = today_minus_7_installation_creation_data.select do | user_installation |
      this_week_installation_ids.include?( user_installation.installation_id )
    end
    today_minus_7_created_installations_active_this_week = retention_1_week_installation_data.count
    retention_1_week = if today_minus_7_created_installations.zero?
      nil
    else
      100 * today_minus_7_created_installations_active_this_week.to_f / today_minus_7_created_installations
    end

    # 2 weeks retention:
    # users that installed the app on day "today-14"
    # and connected at least once between today-7 and today
    retention_2_weeks_installation_data = today_minus_14_installation_creation_data.select do | user_installation |
      this_week_installation_ids.include?( user_installation.installation_id )
    end
    today_minus_14_created_installations_active_this_week = retention_2_weeks_installation_data.count
    retention_2_weeks = if today_minus_14_created_installations.zero?
      nil
    else
      100 * today_minus_14_created_installations_active_this_week.to_f / today_minus_14_created_installations
    end

    # 4 weeks retention:
    # users that installed the app on day "today-28"
    # and connected at least once between today-7 and today
    retention_4_weeks_installation_data = today_minus_28_installation_creation_data.select do | user_installation |
      this_week_installation_ids.include?( user_installation.installation_id )
    end
    today_minus_28_created_installations_active_this_week = retention_4_weeks_installation_data.count
    retention_4_weeks = if today_minus_28_created_installations.zero?
      nil
    else
      100 * today_minus_28_created_installations_active_this_week.to_f / today_minus_28_created_installations
    end

    {
      retention: {
        retention_7_day: retention_7_day,
        retention_14_day: retention_14_day,
        retention_28_day: retention_28_day,
        retention_1_week: retention_1_week,
        retention_2_weeks: retention_2_weeks,
        retention_4_weeks: retention_4_weeks
      },
      active: {
        active_today: today_active_installations,
        active_this_week: this_week_active_installations
      },
      created: {
        created_today_minus_7: today_minus_7_created_installations,
        created_today_minus_14: today_minus_14_created_installations,
        created_today_minus_28: today_minus_28_created_installations
      },
      created_active: {
        created_today_minus_7_active_today: today_minus_7_created_installations_active_today,
        created_today_minus_14_active_today: today_minus_14_created_installations_active_today,
        created_today_minus_28_active_today: today_minus_28_created_installations_active_today,
        created_today_minus_7_active_this_week: today_minus_7_created_installations_active_this_week,
        created_today_minus_14_active_this_week: today_minus_14_created_installations_active_this_week,
        created_today_minus_28_active_this_week: today_minus_28_created_installations_active_this_week
      }
    }
  end
end
