# frozen_string_literal: true

class CohortLifecycle < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true

  def self.process_cohort
    generate_stats_for_date( Time.now.utc.to_date )
  end

  def self.generate_stats_for_date( end_date = Time.now.utc.to_date )
    start_date = end_date - 7.days
    # this ends up being a span of 8 days - the end date and the previous 7 days
    days_to_iterate = ( start_date..end_date ).map( &:to_s )
    # fetch all lifecycles from these dates
    cohort_lifecycles = CohortLifecycle.where( cohort: days_to_iterate )
    # group them by date and user
    grouped_cohort_data = group_cohort_lifecycles_by_cohort_and_user_id( cohort_lifecycles )

    process_days( end_date, start_date, grouped_cohort_data )

    active_users = SegmentationStatistic.generate_segmentation_data_for_interval(
      end_date - 1.day,
      end_date,
      use_database: true
    )

    process_observation_categories_for_date( end_date, grouped_cohort_data, active_users )
    process_retention_for_date( end_date, grouped_cohort_data, active_users )
    observation_array = process_interventions_for_date( end_date, grouped_cohort_data )
    save_cohort_data( grouped_cohort_data )
    process_needs_id( observation_array )
  end

  def self.group_cohort_lifecycles_by_cohort_and_user_id( cohort_lifecycles )
    grouped_cohort_data = {}
    cohort_lifecycles.each do | cohort_lifecycle |
      cohort_date = cohort_lifecycle.cohort.to_s
      user_id = cohort_lifecycle.user_id.to_s.to_sym
      grouped_cohort_data[cohort_date] ||= {}

      grouped_cohort_data[cohort_date][user_id] = cohort_lifecycle.attributes.reject do | k |
        ["id", "cohort", "user_id", "created_at", "updated_at"].include?( k )
      end.symbolize_keys
    end
    grouped_cohort_data
  end

  def self.process_days( end_date, start_date, grouped_cohort_data )
    number_of_days = ( end_date - start_date ).to_i
    number_of_days.times do | day_offset |
      iteration_date = start_date + day_offset.days
      iteration_cohort_date = iteration_date.to_s
      next unless grouped_cohort_data.keys.include?( iteration_cohort_date )

      cohort_day_offset = ( end_date - iteration_date ).to_i
      puts [iteration_cohort_date, cohort_day_offset].join( " " )

      user_ids = grouped_cohort_data[iteration_cohort_date].keys.map( &:to_s ).map( &:to_i )
      obs_data = get_obs( iteration_date, end_date, user_ids )
      categorized_data = categorize_obs_data( obs_data, iteration_date, end_date, user_ids )
      apply_categorized_data_to_cohort(
        grouped_cohort_data,
        iteration_cohort_date,
        categorized_data,
        cohort_day_offset
      )
    end
  end

  def self.process_observation_categories_for_date( date, grouped_cohort_data, active_users )
    active_new_users = active_users.select {| _, v | v[:created_at].zero? }
    obs_data = get_obs( date, date, active_new_users.keys )
    categorized_data = categorize_obs_data( obs_data, date, date, active_new_users.keys )

    cohort_date = date.to_s
    grouped_cohort_data[cohort_date] ||= {}
    apply_categorized_data_to_cohort( grouped_cohort_data, cohort_date, categorized_data, 0 )
  end

  def self.process_retention_for_date( date, grouped_cohort_data, active_users )
    ( 0..7 ).reverse_each do | d |
      retention_cohort_date = ( date - d.days ).to_date.to_s
      next unless grouped_cohort_data[retention_cohort_date]

      grouped_cohort_data[retention_cohort_date].each_value {| v | v["retention"] = nil }
      retention_user_ids = grouped_cohort_data[retention_cohort_date].keys.map( &:to_s ).map( &:to_i )
      retention_users = active_users.select {| k | retention_user_ids.include?( k ) }
      retention_users.each_key do | id |
        user_id = id.to_s.to_sym
        grouped_cohort_data[retention_cohort_date][user_id]["retention"] = true
      end
    end
  end

  def self.process_interventions_for_date( date, grouped_cohort_data )
    # intervention 1: no_obs
    subjects = grouped_cohort_data[date.to_s].select {| _, v | v[:day0] == "no_obs" }
    subjects.each do | key, value |
      next unless value[:observer_appeal_intervention_group].nil?

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
      iteration_cohort_date = ( date - d.days ).to_s
      slot = :"day#{d}"
      prev_slots = ( 0...d ).map {| q | :"day#{q}" }

      puts "#{iteration_cohort_date} #{slot}"
      next unless grouped_cohort_data[iteration_cohort_date]

      # intervention 2: error
      subjects = grouped_cohort_data[iteration_cohort_date].select do | _, v |
        v[slot] == "error" && prev_slots.all? do | prev_slot |
          ["no_obs"].include?( v[prev_slot] )
        end
      end

      subjects.each do | key, value |
        next unless value[:error_intervention_group].nil?

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
      subjects = grouped_cohort_data[iteration_cohort_date].select do | _, v |
        v[slot] == "captives" && prev_slots.all? do | prev_slot |
          ["no_obs", "error", "needs_id"].include?( v[prev_slot] )
        end
      end

      subjects.each do | key, value |
        next unless value[:captive_intervention_group].nil?

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
      subjects = grouped_cohort_data[iteration_cohort_date].select do | _, v |
        v[slot] == "needs_id"
      end

      subjects.each do | key, value |
        user = User.where( id: key.to_s.to_i ).first
        next unless user

        if value[:needs_id_intervention_group].nil?
          group = rand( 2 ).zero? ? "A" : "B"
          value[:needs_id_intervention_group] = group
        end

        next unless group == "A"

        observation_array.concat(
          Observation.
            where( user_id: user.id, quality_grade: "needs_id" ).
            limit( 3 ).
            pluck( :id, :taxon_id )
        )
      end

      # intervention 5: research
      subjects = grouped_cohort_data[iteration_cohort_date].select do | _, v |
        v[slot] == "research" && prev_slots.all? {| prev_slot | v[prev_slot] != "research" }
      end

      subjects.each do | key, value |
        next unless value[:first_observation_intervention_group].nil?

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

  def self.save_cohort_data( grouped_cohort_data )
    grouped_cohort_data.each do | cohort_date, users |
      users.each do | user, data |
        user_id = user.to_s.to_i
        row = CohortLifecycle.where( cohort: cohort_date, user_id: user_id ).first_or_initialize
        row.update!( **data )
      end
    end
  end

  def self.categorize_obs_data( obs_data, start_date, end_date, user_ids )
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
    captives = get_captives( start_date, end_date, casual )
    error = casual - captives

    {
      casual: casual,
      needs_id: needs_id,
      research: research,
      no_obs: no_obs,
      captives: captives,
      error: error
    }
  end

  def self.apply_categorized_data_to_cohort( grouped_cohort_data, cohort_date, categorized_data, cohort_day_offset )
    categorized_data.each do | category, user_ids |
      user_ids.each do | id |
        user_id_sym = id.to_s.to_sym

        # Ensure the cohort and user_id exist in the hash
        grouped_cohort_data[cohort_date] ||= {}
        grouped_cohort_data[cohort_date][user_id_sym] ||= {}

        grouped_cohort_data[cohort_date][user_id_sym][:"day#{cohort_day_offset}"] = category.to_s
      end
    end
  end

  def self.get_obs( start_date, end_date, users )
    return {} if users.empty?

    filter = build_filter( start_date, end_date, users )
    agg = build_agg( users )
    obs_data = fetch_obs_data( filter, agg )
    build_result_hash( obs_data )
  end

  def self.get_captives( start_date, end_date, users )
    return [] if users.empty?

    filter = build_filter( start_date, end_date, users, captives: true )
    agg = build_agg( users )
    obs_data = fetch_obs_data( filter, agg )
    obs_data.map {| a | a["key"] }
  end

  def self.build_filter( start_date, end_date, users, captives: false )
    filter = [
      { range: { created_at: { gte: start_date.beginning_of_day, lte: end_date.end_of_day } } },
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
      quality_counts = observation["quality_grade"]["buckets"].to_h {| q | [q["key"].to_sym, q["doc_count"]] }
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
    results.to_h {| a | [a[:taxon_id], a[:place_ids]] }
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
      params = {
        reviewed: "false",
        quality_grade: "needs_id",
        place_id: "any",
        id: obs_ids.join( "," )
      }
      next unless INatAPIService.observations(
        params.merge( per_page: 0, viewer_id: user_id )
      ).total_results.zero?

      validator.validation_count = nil
      validator.save!
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
