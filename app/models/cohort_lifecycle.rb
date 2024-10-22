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

    start_date = current_day - 1.day
    active_users = SegmentationStatistic.
      generate_segmentation_data_for_interval( start_date, current_day, use_database: true )

    process_current_day( active_users, current_day, cohort_data )
    process_retention( active_users, cohort_data, current_day )
    observation_array = process_interventions( current_day, cohort_data )
    save_cohort_data( cohort_data )
    process_needs_id( observation_array )
  end

  def self.prepare_cohort_data( raw_cohort_data )
    raw_cohort_data.each_with_object( {} ) do | cohort, cohort_data |
      cohort_time = cohort.cohort.to_s
      user_id = cohort.user_id.to_s.to_sym
      cohort_data[cohort_time] ||= {}

      cohort_data[cohort_time][user_id] = {
        day0: cohort.day0,
        day1: cohort.day1,
        day2: cohort.day2,
        day3: cohort.day3,
        day4: cohort.day4,
        day5: cohort.day5,
        day6: cohort.day6,
        day7: cohort.day7,
        retention: cohort.retention,
        observer_appeal_intervention_group: cohort.observer_appeal_intervention_group,
        first_observation_intervention_group: cohort.first_observation_intervention_group,
        error_intervention_group: cohort.error_intervention_group,
        captive_intervention_group: cohort.captive_intervention_group,
        needs_id_intervention_group: cohort.needs_id_intervention_group
      }

      cohort_data
    end
  end

  def self.process_days( cohorts, current_day, window_start, cohort_data )
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

  def self.process_current_day( active_users, current_day, cohort_data )
    active_new_users = active_users.select {| _, v | v[:created_at].zero? }
    obs_data = get_obs( current_day, current_day, active_new_users.keys )
    timespan = [current_day, current_day]
    categorized_data = categorize_obs_data( obs_data, timespan, active_new_users.keys )

    cohort = current_day.to_date.to_s
    cohort_data[cohort] ||= {}
    apply_categorized_data_to_cohort( cohort_data, cohort, categorized_data, 0 )
  end

  def self.process_retention( active_users, cohort_data, current_day )
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

  def self.process_interventions( current_day, cohort_data )
    # intervention 1: no_obs
    cohort = current_day.to_date.to_s
    subjects = cohort_data[cohort].select {| _, v | v[:day0] == "no_obs" }
    subjects.each do | key, value |
      user = User.where( id: key.to_s.to_i ).first
      next unless user

      next unless user.locale =~ /en/

      next if user.email.nil? || !user.suspended_at.nil?

      geoip_response = INatAPIService.geoip_lookup( ip: user.last_ip )
      next unless geoip_response&.results && geoip_response.results.city.present? && geoip_response.results.ll.present?

      geoip_latitude, geoip_longitude = geoip_response.results.ll
      group = rand( 2 ).zero? ? "A" : "B"
      value[:observer_appeal_intervention_group] = group
      next unless group == "A"

      puts "sending...#{user.id}"
      Emailer.observer_appeal( user, latitude: geoip_latitude, longitude: geoip_longitude ).deliver_now
    end

    observation_array = []
    ( 0..6 ).each do | d |
      cohort = ( current_day - ( d * 24 * 60 * 60 ) ).to_date.to_s
      slot = "day#{d}".to_sym
      prev_slots = ( 0...d ).map {| q | "day#{q}".to_sym }

      puts "#{cohort} #{slot}"
      next unless cohort_data[cohort]

      # intervention 2: error
      subjects = cohort_data[cohort].select do | _, v |
        v[slot] == "error" && prev_slots.all? do | prev_slot |
          ["no_obs"].include?( v[prev_slot] )
        end
      end

      subjects.each do | key, value |
        user = User.where( id: key.to_s.to_i ).first
        next unless user

        next unless user.locale =~ /en/

        next if user.email.nil? || !user.suspended_at.nil?

        observation = Observation.where( user_id: user.id, quality_grade: "casual" ).first
        next unless observation

        error_key = {
          "georeferenced" => "location",
          "observed_on" => "date",
          "recent" => "evidence"
        }
        errors = []
        if !observation.georeferenced? || !observation.observed_on? ||
            ( !observation.photos? && !observation.sounds? ) || observation.human? ||
            !observation.quality_metrics_pass?

          missing_fields = ["georeferenced", "observed_on"].reject {| field | observation.public_send( "#{field}?" ) }
          missing_fields << "evidence" unless observation.photos? || observation.sounds?

          if missing_fields.any?
            errors.concat( missing_fields.map {| field | error_key.fetch( field, field ) } )
          elsif ["recent", "evidence", "location", "date"].
              any? do | field |
                ObservationAccuracyExperiment.
                    quality_metric_observation_ids( [observation.id], field ).
                    count == 1
              end
            subset = ["recent", "evidence", "location", "date"].select do | field |
              ObservationAccuracyExperiment.
                quality_metric_observation_ids( [observation.id], field ).
                count == 1
            end
            errors.concat( subset.map {| field | error_key.fetch( field, field ) } )
          elsif ObservationAccuracyExperiment.quality_metric_observation_ids( [observation.id], "subject" ).count == 1
            errors << "single_species"
          end

        elsif !observation.appropriate?
          errors << "evidence"
        end
        errors = errors.uniq

        next unless errors.count.positive?

        group = rand( 2 ).zero? ? "A" : "B"
        value[:error_intervention_group] = group

        next unless group == "A"

        puts "sending...#{user.id}"
        Emailer.error_observation( user, observation, errors: errors ).deliver_now
      end

      # intervention 3: captive
      subjects = cohort_data[cohort].select do | _, v |
        v[slot] == "captives" && prev_slots.all? do | prev_slot |
          ["no_obs", "error", "needs_id"].include?( v[prev_slot] )
        end
      end

      subjects.each do | key, value |
        user = User.where( id: key.to_s.to_i ).first
        next unless user

        next unless user.locale =~ /en/
        next if user.email.nil? || !user.suspended_at.nil?

        observation = Observation.
          joins( :quality_metrics ).
          where( user_id: user.id, quality_grade: "casual" ).
          where( "latitude IS NOT NULL" ).
          where( quality_metrics: { metric: ["wild"] } ).
          group( "observations.id", "quality_metrics.metric" ).
          having( "COUNT(CASE WHEN quality_metrics.agree THEN 1 ELSE NULL END) < " \
            "COUNT(CASE WHEN quality_metrics.agree THEN NULL ELSE 1 END)" ).first
        next unless observation

        group = rand( 2 ).zero? ? "A" : "B"
        value[:captive_intervention_group] = group

        next unless group == "A"

        puts "sending...#{user.id} #{observation.id}"
        Emailer.captive_observation( user, observation ).deliver_now
      end

      # intervention 4: needs_id
      subjects = cohort_data[cohort].select do | _, v |
        v[slot] == "needs_id"
      end

      subjects.each do | key, value |
        user = User.where( id: key.to_s.to_i ).first
        next unless user

        group = rand( 2 ).zero? ? "A" : "B"
        value["needs_id_intervention_group"] = group

        next unless group == "A"

        observation_array.concat(
          Observation.
            where( user_id: user.id, quality_grade: "needs_id" ).
            limit( 3 ).
            pluck( :id, :taxon_id )
        )
      end

      # intervention 5: research
      subjects = cohort_data[cohort].select do | _, v |
        v[slot] == "research" && prev_slots.all? {| prev_slot | v[prev_slot] != "research" }
      end

      subjects.each do | key, value |
        user = User.where( id: key.to_s.to_i ).first
        next unless user

        next unless user.locale =~ /en/

        next if user.email.nil? || !user.suspended_at.nil?

        observation = Observation.where( user_id: user.id, quality_grade: "research" ).first
        next unless observation

        group = rand( 2 ).zero? ? "A" : "B"
        value[:first_observation_intervention_group] = group

        next unless group == "A"

        puts "sending...#{user.id}"
        Emailer.first_observation( user, observation ).deliver_now
      end
    end

    observation_array
  end

  def self.save_cohort_data( cohort_data )
    cohort_data.each do | cohort_date, users |
      users.each do | user, data |
        user_id = user.to_s.to_i
        row = CohortLifecycle.where( cohort: cohort_date, user_id: user_id ).first_or_initialize
        row.update!( **data )
      end
    end
  end

  def self.categorize_obs_data( obs_data, timespan, user_ids )
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

  def self.apply_categorized_data_to_cohort( cohort_data, cohort, categorized_data, cohort_day )
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

  def self.get_obs( start_date, end_date, users )
    return {} if users.empty?

    filter = build_filter( start_date.beginning_of_day, end_date.end_of_day, users )
    agg = build_agg( users )
    obs_data = fetch_obs_data( filter, agg )
    build_result_hash( obs_data )
  end

  def self.get_captives( start_date, end_date, users )
    return [] if users.empty?

    filter = build_filter( start_date.beginning_of_day, end_date.end_of_day, users, captives: true )
    agg = build_agg( users )
    obs_data = fetch_obs_data( filter, agg )
    obs_data.map {| a | a["key"] }
  end

  def self.build_filter( start_time, end_time, users, captives: false )
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

  def self.build_agg( users )
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

  def self.fetch_obs_data( filter, agg )
    Observation.elastic_search(
      size: 0,
      filters: filter,
      aggregate: agg
    ).response.aggregations.user_id.buckets
  end

  def self.build_result_hash( obs_data )
    result_hash = {}

    obs_data.each do | observation |
      user_id = observation["key"]
      quality_counts = observation["quality_grade"]["buckets"].map {| q | [q["key"].to_sym, q["doc_count"]] }.to_h
      result_hash[user_id] = quality_counts
    end

    result_hash
  end

  def self.get_improving_identifiers( user_id, place_ids )
    filter = [
      {
        bool: {
          must: [
            { term: { category: "improving" } },
            { term: { "taxon.rank": "species" } },
            { term: { own_observation: false } },
            { term: { "user.id": user_id } }
          ]
        }
      }
    ]

    aggregation = {
      taxon_id: {
        terms: {
          field: "taxon.id",
          size: 10_000,
          min_doc_count: 3
        },
        aggs: {
          place_ids: {
            terms: {
              field: "observation.place_ids",
              size: 10_000,
              min_doc_count: 1
            }
          }
        }
      }
    }

    response = Identification.elastic_search(
      size: 0,
      filters: filter,
      aggregate: aggregation
    ).response.aggregations.taxon_id.buckets

    results = response.map do | taxon_bucket |
      {
        taxon_id: taxon_bucket["key"],
        place_ids: taxon_bucket.place_ids.buckets.map {| place_bucket | place_bucket["key"] } & place_ids
      }
    end
    results.map {| a | [a[:taxon_id], a[:place_ids]] }.to_h
  end

  def self.get_place_obs( observation_ids, place_ids )
    batch_size = 500
    total_elapsed_time = 0
    observation_places = []
    ( 0..observation_ids.length - 1 ).step( batch_size ) do | i |
      start_time = Time.now
      batch_observation_ids = observation_ids[i, batch_size]
      batch_observation_places = ObservationsPlace.
        where( observation_id: batch_observation_ids, place_id: place_ids ).
        pluck( :observation_id, :place_id )
      observation_places.concat( batch_observation_places )
      end_time = Time.now
      elapsed_time = end_time - start_time
      total_elapsed_time += elapsed_time
    end
    puts "Total time: #{total_elapsed_time} seconds"
    puts "Average time per batch: #{total_elapsed_time / ( observation_ids.length.to_f / batch_size )} seconds"
    observation_places.to_h
  end

  def self.prepare_observations( observation_array, place_ids )
    admin = User.where( email: CONFIG.admin_user_email ).first
    return false unless admin

    place_obs = get_place_obs( observation_array.map {| o | o[0] }, place_ids )
    place_hash = place_obs.to_h
    taxon_hash = observation_array.to_h
    rank_hash = Taxon.find( observation_array.map {| o | o[1] }.uniq.compact ).pluck( :id, :rank_level ).to_h
    new_taxon_hash = {}
    observation_array.each do | row |
      obs_id = row[0]
      old_taxon_id = taxon_hash[obs_id]
      if ( old_taxon_id.nil? || rank_hash[old_taxon_id] > 10 ) && new_taxon_hash[obs_id].nil?
        begin
          data = INatAPIService.score_observation( obs_id )
          taxa = data["results"].select {| r | r["taxon"]["rank"] == "species" }.map {| r | r["taxon"]["id"] }
          taxon_id = taxa[0]
          new_taxon_hash[obs_id] = taxon_id
        rescue NoMethodError
          puts "no photos"
          new_taxon_hash[obs_id] = old_taxon_id
        end
      else
        new_taxon_hash[obs_id] = old_taxon_id
      end
    end

    prepared_obs = []
    observation_array.map {| o | o[0] }.select do | obs |
      place_id = place_hash[obs]
      taxon_id = new_taxon_hash[obs]
      next unless taxon_id

      prepared_obs << { id: obs, place_id: place_id, taxon_id: taxon_id }
    end
    prepared_obs
  end

  def self.store_prepared_observations( prepared_obs, needs_id_pilot )
    ObservationAccuracySample.where( observation_accuracy_experiment_id: needs_id_pilot.id ).
      where( "observation_id NOT IN (?)", prepared_obs.map {| row | row[:id] }.uniq ).destroy_all
    prepared_obs.each do | row |
      sample = ObservationAccuracySample.
        where( observation_accuracy_experiment_id: needs_id_pilot.id ).
        where( observation_id: row[:id] ).first
      next if sample

      sample = ObservationAccuracySample.new(
        observation_accuracy_experiment_id: needs_id_pilot.id,
        observation_id: row[:id]
      )
      sample.save!
    end
  end

  def self.assign_to_iders( needs_id_pilot, place_ids, prepared_obs )
    active_iders = Preference.where(
      "owner_type = 'User' AND name = 'needs_id_pilot' AND value = 't'"
    ).pluck( :owner_id )
    ObservationAccuracyValidator.where( observation_accuracy_experiment_id: needs_id_pilot.id ).
      where( "user_id NOT IN (?)", active_iders ).destroy_all
    active_iders.each do | user_id |
      validator = ObservationAccuracyValidator.
        where( observation_accuracy_experiment_id: needs_id_pilot.id ).
        where( user_id: user_id ).first
      unless validator
        validator = ObservationAccuracyValidator.new(
          observation_accuracy_experiment_id: needs_id_pilot.id,
          user_id: user_id
        )
        validator.save!
      end
      id_matches = get_improving_identifiers( user_id, place_ids )
      filtered_obs_ids = prepared_obs.select do | obs |
        place_id = obs[:place_id]
        taxon_id = obs[:taxon_id]
        id_matches[taxon_id]&.include?( place_id )
      end
      obs_ids = filtered_obs_ids.map {| a | a[:id] }.sample( 30 )
      samples = ObservationAccuracySample.
        where( observation_accuracy_experiment_id: needs_id_pilot.id ).
        where( "observation_id IN (?)", obs_ids )
      validator.observation_accuracy_samples << samples
    end
  end

  def self.process_needs_id( observation_array )
    puts "processing needs_id..."
    needs_id_pilot = ObservationAccuracyExperiment.needs_id_pilot
    needs_id_pilot ||= ObservationAccuracyExperiment.create(
      version: ObservationAccuracyExperiment::NEEDS_ID_PILOT_VERSION
    )
    place_ids = Place.where( admin_level: Place::COUNTRY_LEVEL ).pluck( :id )
    puts "\tpreparing observations..."
    prepared_obs = prepare_observations( observation_array, place_ids )
    puts "\tstoring prepared observations..."
    store_prepared_observations( prepared_obs, needs_id_pilot )
    puts "\tassigning to iders..."
    assign_to_iders( needs_id_pilot, place_ids, prepared_obs )
  end
end
