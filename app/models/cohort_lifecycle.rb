# frozen_string_literal: true

class CohortLifecycle < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true

  def self.process_cohort
    current_day = Time.now.utc.end_of_day
    window_start = current_day - 7.days

    current_days_to_iterate = ( window_start.to_date..current_day.to_date ).map( &:to_s )
    raw_cohort_data = CohortLifecycle.where( cohort: current_days_to_iterate )

    cohort_data = prepare_cohort_data( raw_cohort_data )

    cohorts = cohort_data.keys.uniq

    process_days( cohorts, current_day, window_start, cohort_data )

    process_current_day( current_day, cohort_data )

    process_retention( cohort_data, current_day )

    save_cohort_data( cohort_data )
  end

  def self.prepare_cohort_data( raw_cohort_data )
    cohort_data = {}
    raw_cohort_data.each do | cohort |
      cohort_time = cohort.cohort.to_s
      user_id = cohort.user_id
      cohort_data[cohort_time] ||= {}
      cohort_data[cohort_time][user_id.to_sym] = cohort.
        attributes.except( "id", "created_at", "updated_at", "cohort", "user_id" ).
        transform_keys( &:to_sym )
    end
    cohort_data
  end

  def self.process_days( cohorts, current_day, window_start, cohort_data )
    ( ( current_day - window_start ) / ( 60 * 60 * 24 ) ).to_i.times do | i |
      current_day_to_iterate = window_start + i.days
      cohorts.each do | cohort |
        next unless cohort == current_day_to_iterate.to_date.to_s

        cohort_day = ( ( current_day - current_day_to_iterate ) / ( 60 * 60 * 24 ) ).to_i
        puts [cohort, cohort_day].join( " " )

        user_ids = cohort_data[cohort].keys.map( &:to_s ).map( &:to_i )
        obs_data = get_obs_span( current_day_to_iterate, current_day, user_ids )

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
        no_obs = ( user_ids - casual - needs_id - research )

        captives = get_captives_span( current_day_to_iterate, current_day, casual )
        error = casual - captives

        no_obs.each {| id | cohort_data[cohort][id.to_s.to_sym]["day#{cohort_day}"] = "no_obs" }
        error.each {| id | cohort_data[cohort][id.to_s.to_sym]["day#{cohort_day}"] = "error" }
        captives.each {| id | cohort_data[cohort][id.to_s.to_sym]["day#{cohort_day}"] = "captives" }
        needs_id.each {| id | cohort_data[cohort][id.to_s.to_sym]["day#{cohort_day}"] = "needs_id" }
        research.each {| id | cohort_data[cohort][id.to_s.to_sym]["day#{cohort_day}"] = "research" }
      end
    end
  end

  def self.process_current_day( current_day, cohort_data )
    start_date = current_day - 1.day
    active_users = SegmentationStatistic.
      generate_segmentation_data_for_interval( start_date, current_day, use_database: true )
    active_new_users = active_users.select {| _, v | v[:created_at].zero? }

    obs_data = get_obs( current_day, active_new_users.keys )

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
    no_obs = ( active_new_users.keys - casual - needs_id - research )

    if casual.count.positive?
      captives = get_captives( current_day, casual )
      error = casual - captives
    else
      captives = []
      error = []
    end

    cohort = current_day.to_date.to_s
    cohort_data[cohort] ||= {}
    initialize_and_set( cohort_data, cohort, no_obs, "no_obs" )
    initialize_and_set( cohort_data, cohort, error, "error" )
    initialize_and_set( cohort_data, cohort, captives, "captives" )
    initialize_and_set( cohort_data, cohort, needs_id, "needs_id" )
    initialize_and_set( cohort_data, cohort, research, "research" )
  end

  def self.process_retention( cohort_data, current_day )
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

  def self.save_cohort_data( cohort_data )
    cohort_data.each do | cohort_date, users |
      users.each do | user_id, data |
        row = CohortLifecycle.where( cohort: cohort_date, user_id: user_id ).first
        if row
          row.update( data: data.keys )
        else
          row = CohortLifecycle.new( cohort: cohort_date, user_id: user_id, data: data.keys )
          row.save!
        end
      end
    end
  end

  private

  def get_obs( day, users )
    filter = build_filter( day.beginning_of_day, day.end_of_day, users )
    agg = build_agg( users )

    obs_data = fetch_obs_data( filter, agg )

    build_result_hash( obs_data )
  end

  def get_captives( day, users )
    filter = build_filter( day.beginning_of_day, day.end_of_day, users, captives: true )
    agg = build_agg( users )

    obs_data = fetch_obs_data( filter, agg )

    obs_data.map {| a | a["key"] }
  end

  def get_obs_span( start_date, end_date, users )
    filter = build_filter( start_date.beginning_of_day, end_date.end_of_day, users )
    agg = build_agg( users )

    obs_data = fetch_obs_data( filter, agg )

    build_result_hash( obs_data )
  end

  def get_captives_span( start_date, end_date, users )
    filter = build_filter( start_date.beginning_of_day, end_date.end_of_day, users, captives: true )
    agg = build_agg( users )

    obs_data = fetch_obs_data( filter, agg )

    obs_data.map {| a | a["key"] }
  end

  def build_filter( start_time, end_time, users, captives: false )
    filter = [
      {
        range: {
          created_at: {
            gte: start_time,
            lte: end_time
          }
        }
      },
      {
        terms: {
          "user.id": users
        }
      }
    ]

    if captives
      filter += [
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

    filter
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

  def initialize_and_set( cohort_data, cohort, ids, value )
    ids.each do | id |
      user_id = id.to_s.to_sym
      cohort_data[cohort][user_id] ||= {}
      cohort_data[cohort][user_id]["day0"] = value
    end
  end

  def quality_metric_observation_ids( observation_ids, metrics )
    QualityMetric.
      select( :observation_id ).
      where( observation_id: observation_ids, metric: metrics ).
      group( :observation_id, :metric ).
      having(
        "COUNT( CASE WHEN agree THEN 1 ELSE NULL END ) < COUNT( CASE WHEN agree THEN NULL ELSE 1 END )"
      ).
      distinct.pluck( :observation_id )
  end
end
