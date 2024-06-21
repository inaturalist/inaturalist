# frozen_string_literal: true

class CohortLifecycle < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true

  def process_cohort
    current_day = Time.now.utc.end_of_day
    window_start = current_day - 7.days
    current_days_to_iterate = ( window_start.to_date..current_day.to_date ).map( &:to_s )
    raw_cohort_data = CohortLifecycle.where( cohort: current_days_to_iterate )

    cohort_data = prepare_cohort_data( raw_cohort_data )
    cohorts = cohort_data.keys.uniq

    process_days( cohorts, current_day, window_start, cohort_data )

    start_date = current_day - 1.day
    active_users = SegmentationStatistic.
      generate_segmentation_data_for_interval( start_date, current_day, use_database: true )

    process_current_day( active_users, current_day, cohort_data )
    process_retention( active_users, cohort_data, current_day )

    save_cohort_data( cohort_data )
  end

  def prepare_cohort_data( raw_cohort_data )
    cohort_data = {}
    raw_cohort_data.each do | cohort |
      cohort_time = cohort.cohort.to_s
      user_id = cohort.user_id
      cohort_data[cohort_time] ||= {}
      cohort_data[cohort_time][user_id.to_s.to_sym] = cohort.
        attributes.except( "id", "created_at", "updated_at", "cohort", "user_id" ).
        transform_keys( &:to_sym )
    end
    cohort_data
  end

  def process_days( cohorts, current_day, window_start, cohort_data )
    ( ( current_day - window_start ) / ( 60 * 60 * 24 ) ).to_i.times do | i |
      current_day_to_iterate = window_start + i.days
      cohorts.each do | cohort |
        next unless cohort == current_day_to_iterate.to_date.to_s

        cohort_day = ( ( current_day - current_day_to_iterate ) / ( 60 * 60 * 24 ) ).to_i
        puts [cohort, cohort_day].join( " " )

        user_ids = cohort_data[cohort].keys.map( &:to_s ).map( &:to_i )
        obs_data = get_obs( current_day_to_iterate, current_day, user_ids )
        timespan = [current_day_to_iterate, current_day]
        categorized_data = categorize_obs_data( obs_data, timespan, user_ids )
        apply_categorized_data_to_cohort( cohort_data, cohort, categorized_data, cohort_day )
      end
    end
  end

  def process_current_day( active_users, current_day, cohort_data )
    active_new_users = active_users.select {| _, v | v[:created_at].zero? }
    obs_data = get_obs( current_day, current_day, active_new_users.keys )
    timespan = [current_day, current_day]
    categorized_data = categorize_obs_data( obs_data, timespan, active_new_users.keys )

    cohort = current_day.to_date.to_s
    cohort_data[cohort] ||= {}
    apply_categorized_data_to_cohort( cohort_data, cohort, categorized_data, 0 )
  end

  def process_retention( active_users, cohort_data, current_day )
    ( 0..7 ).reverse_each do | d |
      retention_cohort = ( current_day - d.days ).to_date.to_s
      next unless cohort_data[retention_cohort]

      cohort_data[retention_cohort].each {| _, v | v["retention"] = nil }
      retention_user_ids = cohort_data[retention_cohort].keys.map( &:to_s ).map( &:to_i )
      retention_users = active_users.select {| k, _ | retention_user_ids.include?( k ) }
      retention_users.each_key do | id |
        user_id = id.to_s.to_sym
        cohort_data[retention_cohort][user_id]["retention"] = true
      end
    end
  end

  def save_cohort_data( cohort_data )
    cohort_data.each do | cohort_date, users |
      users.each do | user, data |
        user_id = user.to_s.to_i
        row = CohortLifecycle.where( cohort: cohort_date, user_id: user_id ).first_or_initialize
        row.update!( **data )
      end
    end
  end

  private

  def categorize_obs_data( obs_data, timespan, user_ids )
    casual = obs_data.
      select do | _, v |
        ( v[:needs_id].nil? || v[:needs_id].zero? ) &&
          ( v[:research].nil? || v[:research].zero? )
      end.keys
    needs_id = obs_data.
      select do | _, v |
        !v[:needs_id].nil? &&
          v[:needs_id].positive? &&
          ( v[:research].nil? || v[:research].zero? )
      end.keys
    research = obs_data.select {| _, v | v[:research]&.positive? }.keys
    no_obs = user_ids - casual - needs_id - research
    captives = get_captives( timespan[0], timespan[1], casual )
    error = casual - captives

    { casual: casual, needs_id: needs_id, research: research, no_obs: no_obs, captives: captives, error: error }
  end

  def apply_categorized_data_to_cohort( cohort_data, cohort, categorized_data, cohort_day )
    categorized_data.each do | category, user_ids |
      user_ids.each do | id |
        user_id_sym = id.to_s.to_sym

        # Ensure the cohort and user_id exist in the hash
        cohort_data[cohort] ||= {}
        cohort_data[cohort][user_id_sym] ||= {}

        cohort_data[cohort][user_id_sym]["day#{cohort_day}".to_sym] = category.to_s
      end
    end
  end

  def get_obs( start_date, end_date, users )
    filter = build_filter( start_date.beginning_of_day, end_date.end_of_day, users )
    agg = build_agg( users )
    obs_data = fetch_obs_data( filter, agg )
    build_result_hash( obs_data )
  end

  def get_captives( start_date, end_date, users )
    filter = build_filter( start_date.beginning_of_day, end_date.end_of_day, users, captives: true )
    agg = build_agg( users )
    obs_data = fetch_obs_data( filter, agg )
    obs_data.map {| a | a["key"] }
  end

  def build_filter( start_time, end_time, users, captives: false )
    filter = [
      { range: { created_at: { gte: start_time, lte: end_time } } },
      { terms: { "user.id": users } }
    ]
    return filter unless captives

    filter + [
      { exists: { field: "observed_on" } },
      { exists: { field: "location" } },
      {
        bool: {
          should: [
            { term: { captive: true } },
            { term: { "taxon.id": Taxon::HUMAN.id } },
            { term: { "taxon.id": Taxon::HOMO.id } }
          ],
          minimum_should_match: 1
        }
      },
      {
        bool: {
          should: [
            { range: { photos_count: { gt: 0 } } },
            { range: { sounds_count: { gt: 0 } } }
          ]
        }
      }
    ]
  end

  def build_agg( users )
    {
      user_id: {
        terms: {
          field: "user.id",
          size: users.count
        },
        aggs: {
          quality_grade: {
            terms: {
              field: "quality_grade",
              size: 100
            }
          }
        }
      }
    }
  end

  def fetch_obs_data( filter, agg )
    Observation.elastic_search(
      size: 0,
      filters: filter,
      aggregate: agg
    ).response.aggregations.user_id.buckets
  end

  def build_result_hash( obs_data )
    result_hash = {}

    obs_data.each do | observation |
      user_id = observation["key"]
      quality_counts = observation["quality_grade"]["buckets"].map {| q | [q["key"].to_sym, q["doc_count"]] }.to_h
      result_hash[user_id] = quality_counts
    end

    result_hash
  end
end
