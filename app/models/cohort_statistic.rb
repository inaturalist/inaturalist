# frozen_string_literal: true

class CohortStatistic < ApplicationRecord
  STAT_TYPES = %w(acquisition behavior).freeze
  validates :stat_type, presence: true, inclusion: { in: STAT_TYPES }

  # Acquisition cohort statistics
  #   generated on last day of the month
  #
  def self.generate_acquisition_cohorts_stats( at_time = Time.now, options = {} )
    at_time = at_time.utc.end_of_day
    scope = CohortStatistic.where( "DATE(created_at) = DATE(?)", at_time.utc ).
      where( stat_type: "acquisition" )
    if options[:force]
      scope.delete_all
    elsif scope.exists?
      return
    end
    sleep 1
    CohortStatistic.create!(
      stat_type: "acquisition",
      data: get_acquisition_cohorts,
      created_at: at_time.beginning_of_day
    )
  end

  # Behavior cohort statistics
  #   generated on 10th, 20th, and last day of the month
  #
  def self.generate_behavior_cohorts_stats( at_time = Time.now, options = {} )
    at_time = at_time.utc.end_of_day
    scope = CohortStatistic.where( "DATE(created_at) = DATE(?)", at_time.utc ).
      where( stat_type: "behavior" )
    if options[:force]
      scope.delete_all
    elsif scope.exists?
      return
    end
    sleep 1
    CohortStatistic.create!(
      stat_type: "behavior",
      data: get_behavior_cohorts,
      created_at: at_time.beginning_of_day
    )
  end

  # private

  # Get the acquisition cohorts
  # since the begining of iNaturalist
  # ex:  2008
  #                created_users_in_2008
  #                active_users_2008 / created_users_in_2008
  #                active_users_2009 / created_users_in_2008
  #                ...
  #                active_users_2024 / created_users_in_2008
  #                active_users_2025 / created_users_in_2008
  #      2009
  #                created_users_in_2009
  #                active_users_2009 / created_users_in_2009
  #                active_users_2010 / created_users_in_2009
  #                ...
  #                active_users_2024 / created_users_in_2009
  #                active_users_2025 / created_users_in_2009
  #      ...
  #      2024
  #                active_users_2024 / created_users_in_2024
  #                active_users_2025 / created_users_in_2024
  #      2025
  #                created_users_in_2025
  #                active_users_2025 / created_users_in_2024
  #
  def self.get_acquisition_cohorts
    created_users = get_all_yearly_created_users
    active_users = get_all_yearly_active_users

    year_keys = created_users.keys.sort
    acquisition_cohorts = {}
    globally_active_users = active_users.values.flat_map {| data | data[:active_users] }.uniq

    created_users.each do | key, data |
      start_index = year_keys.index( key )
      next unless start_index

      future_year_keys = year_keys[start_index..]
      base_cohort = data[:created_users] & globally_active_users
      next if base_cohort.empty?

      acquisitions = future_year_keys.map do | year_key |
        year_data = active_users[year_key]
        next unless year_data

        cohort_size = base_cohort.count
        active_count = ( base_cohort & year_data[:active_users] ).count
        {
          key: year_key,
          label: year_data[:label],
          count: active_count,
          percent: cohort_size.positive? ? ( active_count.to_f / cohort_size ) : 0
        }
      end.compact

      acquisition_cohorts[key] = {
        label: data[:label],
        cohort_count: base_cohort.count,
        acquisitions: acquisitions
      }
    end

    acquisition_cohorts
  end

  # Get the list of users (user_id) created per year
  # since the begining of iNaturalist
  #
  def self.get_all_yearly_created_users
    start_year = 2008
    end_year = Time.current.year
    created_users_by_year = {}

    ( start_year..end_year ).each do | year |
      year_start = Time.zone.local( year ).beginning_of_year
      year_end = year_start.end_of_year
      key = year.to_s
      created_users_by_year[key] = {
        label: year.to_s,
        start_at: year_start,
        end_at: year_end,
        created_users: get_yearly_created_users( year_start, year_end )
      }
    end

    created_users_by_year
  end

  # Get the list of users (user_id) created during a selected year
  #
  def self.get_yearly_created_users( start_of_year, end_of_year )
    User.where( created_at: start_of_year..end_of_year ).distinct.pluck( :id )
  end

  # Get the list of users (user_id) active per year
  # since the begining of iNaturalist
  #
  def self.get_all_yearly_active_users
    start_year = 2008
    end_year = Time.current.year
    active_users_by_year = {}

    ( start_year..end_year ).each do | year |
      year_start = Time.zone.local( year ).beginning_of_year
      year_end = year_start.end_of_year
      year_key = year.to_s

      active_users = []
      12.times do | month_index |
        month_start = ( year_start + month_index.months ).beginning_of_month
        break if month_start > Time.current

        month_end = month_start.end_of_month.end_of_day
        active_users |= get_monthly_active_users( month_start, month_end )
      end

      active_users_by_year[year_key] = {
        label: year.to_s,
        start_at: year_start,
        end_at: year_end,
        active_users: active_users
      }
    end

    active_users_by_year
  end

  # Get the 25 behavior cohorts
  # ex:  2023_11
  #                2023_11 active_users_in_november_2023 / cohort_november_2023
  #                2023_12 active_users_in_december_2023 / cohort_november_2023
  #                ...
  #                2025_10 active_users_in_october_2025 / cohort_november_2023
  #                2025_11 active_users_in_november_2025 / cohort_november_2023
  #      2023_12
  #                2023_12 active_users_in_december_2023 / cohort_december_2023
  #                2024_01 active_users_in_january_2024 / cohort_december_2023
  #                ...
  #                2025_10 active_users_in_october_2025 / cohort_december_2023
  #                2025_11 active_users_in_november_2025 / cohort_december_2023
  #      ...
  #      2025_10
  #                2025_10 active_users_in_october_2025 / cohort_october_2025
  #                2025_11 active_users_in_november_2025 / cohort_october_2025
  #      2025_11
  #                2025_11 active_users_in_november_2025 / cohort_november_2025
  #
  def self.get_behavior_cohorts
    active_users = get_25_monthly_active_users
    precohort = active_users["precohort"][:active_users]
    cohorts = get_cohorts_from_active_users( active_users, precohort )
    month_keys = active_users.keys
    behavior_cohorts = {}

    cohorts.each do | key, data |
      start_index = month_keys.index( key )
      next unless start_index

      behaviors = []
      ( 0..24 ).each do | offset |
        month_key = month_keys[start_index + offset]
        break unless month_key

        month_data = active_users[month_key]
        intersection = data[:cohort] & month_data[:active_users]
        behaviors << {
          key: month_key,
          label: month_data[:label],
          count: intersection.count,
          percent: intersection.count.to_f / data[:cohort].count
        }
      end

      behavior_cohorts[key] = {
        label: data[:label],
        cohort_count: data[:cohort].count,
        behaviors: behaviors
      }
    end

    behavior_cohorts
  end

  # Get the 25 cohorts
  # ex:  2023_11 active_users_in_november_2023
  #      2023_12 active_users_in_december_2023 - active_users_in_november_2023
  #      2024_01 active_users_in_january_2024 - active_users_in_december_2023 - active_users_in_november_2023
  #      ...
  #      2025_10 active_users_in_october_2025 - active_users_in_september_2025 - active_users_in_august_2025 - ...
  #      2025_11 active_users_in_november_2025 - active_users_in_october_2025 - active_users_in_september_2025 - ...
  #
  def self.get_cohorts_from_active_users( active_users, seen_users )
    cohorts = {}
    active_users.each do | key, data |
      cohort = data[:active_users] - seen_users
      cohorts[key] = {
        label: data[:label],
        cohort: cohort
      }
      seen_users |= data[:active_users]
    end
    cohorts
  end

  # Get the 25 months of active users
  # ex:  2023_11 active_users_in_november_2023
  #      2023_12 active_users_in_december_2023
  #      2024_01 active_users_in_january_2024
  #      ...
  #      2025_10 active_users_in_october_2025
  #      2025_11 active_users_in_november_2025
  #
  def self.get_25_monthly_active_users
    now = Time.current.beginning_of_month
    active_users = {}
    24.downto( 0 ).each do | months_ago |
      month_start = ( now - months_ago.months ).beginning_of_month
      month_end = month_start.end_of_month.end_of_day
      key = month_start.strftime( "%Y_%m" )
      active_users[key] = {
        label: month_start.strftime( "%B %Y" ),
        start_at: month_start,
        end_at: month_end,
        active_users: get_monthly_active_users( month_start, month_end )
      }
    end

    earliest_month = active_users.values.map {| data | data[:start_at] }.min
    historical_users = []
    if earliest_month
      current_month = Time.zone.local( 2008 ).beginning_of_month
      while current_month < earliest_month
        month_end = current_month.end_of_month.end_of_day
        historical_users |= get_monthly_active_users( current_month, month_end )
        current_month = ( current_month + 1.month ).beginning_of_month
      end
    end

    active_users.merge(
      "precohort" => {
        label: "Active before #{active_users.keys.first}",
        start_at: nil,
        end_at: earliest_month,
        active_users: historical_users
      }
    )
  end

  # Get the list of users (user_id) active during a selected month
  #
  def self.get_monthly_active_users( start_of_month, end_of_month )
    puts "search #{start_of_month} to #{end_of_month}"
    active_from_observations = Observation.elastic_search(
      size: 0,
      filters: [
        {
          range: {
            created_at: {
              gte: start_of_month,
              lte: end_of_month
            }
          }
        }
      ],
      aggregate: {
        user_id: {
          terms: { field: "user.id", size: 10_000_000 }
        }
      }
    ).response.aggregations.user_id.
      buckets.map do | b |
      b["key"]
    end
    puts "active_from_observations: #{active_from_observations.count}"
    active_from_identifications = Identification.elastic_search(
      size: 0,
      filters: [
        {
          range: {
            created_at: {
              gte: start_of_month,
              lte: end_of_month
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
      ],
      aggregate: {
        user_id: {
          terms: { field: "user.id", size: 10_000_000 }
        }
      }
    ).response.aggregations.user_id.
      buckets.map do | b |
      b["key"]
    end
    puts "active_from_identifications: #{active_from_identifications.count}"
    active_from_comments = Comment.select( "DISTINCT(user_id)" ).
      where( created_at: start_of_month..end_of_month ).
      collect( &:user_id )
    active_from_posts = Post.select( "DISTINCT(user_id)" ).
      where( created_at: start_of_month..end_of_month ).
      collect( &:user_id )
    ( active_from_observations + active_from_identifications + active_from_comments + active_from_posts ).uniq
  end
end
