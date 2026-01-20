# frozen_string_literal: true

class CohortStatistic < ApplicationRecord
  STAT_TYPES = %w(acquisition behavior segment_active_users).freeze
  validates :stat_type, presence: true, inclusion: { in: STAT_TYPES }

  # Acquisition cohort statistics
  #   generated on last day of the month
  #
  def self.generate_acquisition_cohorts_stats( at_time = Time.now, options = {} )
    at_time = at_time.utc.end_of_day
    scope = CohortStatistic.where( "DATE(created_at) = DATE(?)", at_time ).
      where( stat_type: "acquisition" )
    if options[:force]
      scope.delete_all
    elsif scope.exists?
      return
    end
    sleep 1
    CohortStatistic.create!(
      stat_type: "acquisition",
      data: get_acquisition_cohorts( at_time ),
      created_at: at_time
    )
  end

  # Behavior cohort statistics
  #   generated on 10th, 20th, and last day of the month
  #
  def self.generate_behavior_cohorts_stats( at_time = Time.now, options = {} )
    at_time = at_time.utc.end_of_day
    scope = CohortStatistic.where( "DATE(created_at) = DATE(?)", at_time ).
      where( stat_type: "behavior" )
    if options[:force]
      scope.delete_all
    elsif scope.exists?
      return
    end
    sleep 1
    CohortStatistic.create!(
      stat_type: "behavior",
      data: get_behavior_cohorts( at_time ),
      created_at: at_time
    )
  end

  # Segment active users statistics
  #   generated on last day of the month
  #
  def self.generate_segment_active_users_stats( at_time = Time.now, options = {} )
    at_time = at_time.utc.end_of_day
    scope = CohortStatistic.where( "DATE(created_at) = DATE(?)", at_time ).
      where( stat_type: "segment_active_users" )
    if options[:force]
      scope.delete_all
    elsif scope.exists?
      return
    end
    sleep 1
    CohortStatistic.create!(
      stat_type: "segment_active_users",
      data: get_segment_active_users( at_time ),
      created_at: at_time
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
  def self.get_acquisition_cohorts( at_time = Time.current.utc )
    created_users = get_all_yearly_created_users( at_time )
    active_users = get_all_yearly_active_users( at_time )

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
  # since the begining of iNaturalist up to at_time
  # (the last period ends on at_time)
  #
  def self.get_all_yearly_created_users( at_time = Time.current.utc )
    start_year = 2008
    end_year = at_time.year
    created_users_by_year = {}

    ( start_year..end_year ).each do | year |
      start_at = Time.utc( year ).beginning_of_year
      end_at = ( year == end_year ) ? at_time.end_of_day : start_at.end_of_year
      year_key = year.to_s
      created_users_by_year[year_key] = {
        label: year.to_s,
        start_at: start_at,
        end_at: end_at,
        created_users: User.where( created_at: start_at..end_at ).distinct.pluck( :id )
      }
    end

    created_users_by_year
  end

  # Get the list of users (user_id) active per year
  # since the begining of iNaturalist up to at_time
  # (the last period ends on at_time)
  #
  def self.get_all_yearly_active_users( at_time = Time.current.utc )
    start_year = 2008
    end_year = at_time.year
    active_users_by_year = {}

    ( start_year..end_year ).each do | year |
      start_at = Time.utc( year ).beginning_of_year
      end_at = ( year == end_year ) ? at_time.end_of_day : start_at.end_of_year
      year_key = year.to_s

      active_users = []
      12.times do | month_index |
        month_start = ( start_at + month_index.months ).beginning_of_month
        break if month_start > at_time

        month_end = month_start.end_of_month.end_of_day
        if year == end_year && month_start.month == at_time.month
          month_end = at_time.end_of_day
        end
        active_users |= get_monthly_active_users( month_start, month_end )
      end

      active_users_by_year[year_key] = {
        label: year.to_s,
        start_at: start_at,
        end_at: end_at,
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
  def self.get_behavior_cohorts( at_time = Time.current.utc )
    active_users = get_25_monthly_active_users( at_time )
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

  # Segment monthly active users into:
  #   new (first activity this month),
  #   retained (active this month and last month),
  #   re-engaged (active this month but not last month)
  #
  def self.get_segment_active_users( at_time = Time.current.utc )
    active_users = get_25_monthly_active_users( at_time )
    month_keys = active_users.keys.reject {| key | key == "precohort" }
    seen_users = active_users["precohort"] ? active_users["precohort"][:active_users].dup : []
    prev_active_for_first_month = []
    if month_keys.first
      first_month = active_users[month_keys.first]
      prev_month_start = ( first_month[:start_at] - 1.month ).beginning_of_month
      prev_month_end = prev_month_start.end_of_month.end_of_day
      prev_active_for_first_month = get_monthly_active_users(
        prev_month_start,
        prev_month_end
      )
    end
    segment_active_users = {}

    month_keys.each_with_index do | key, index |
      month_data = active_users[key]
      month_active = month_data[:active_users]
      prev_key = index.zero? ? nil : month_keys[index - 1]
      prev_active = prev_key ? active_users[prev_key][:active_users] : prev_active_for_first_month

      new_users = month_active - seen_users
      retained_users = prev_active.empty? ? [] : ( month_active & prev_active )
      reengaged_users = month_active - prev_active - new_users

      segment_active_users[key] = {
        label: month_data[:label],
        start_at: month_data[:start_at],
        end_at: month_data[:end_at],
        active: month_active.count,
        new: new_users.count,
        retained: retained_users.count,
        reengaged: reengaged_users.count
      }

      seen_users |= month_active
    end

    segment_active_users
  end

  # Get the 25 months of active users
  # ex:  2023_11 active_users_in_november_2023
  #      2023_12 active_users_in_december_2023
  #      2024_01 active_users_in_january_2024
  #      ...
  #      2025_10 active_users_in_october_2025
  #      2025_11 active_users_in_november_2025
  #
  def self.get_25_monthly_active_users( at_time = Time.current.utc )
    active_users = {}
    24.downto( 0 ).each do | months_ago |
      month_start = ( at_time - months_ago.months ).beginning_of_month
      month_end = months_ago.zero? ? at_time.end_of_day : month_start.end_of_month.end_of_day
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
      current_month = Time.utc( 2008 ).beginning_of_month
      while current_month < earliest_month
        month_end = current_month.end_of_month.end_of_day
        historical_users |= get_monthly_active_users(
          current_month,
          month_end
        )
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
