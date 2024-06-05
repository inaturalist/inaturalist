# frozen_string_literal: true

require "rubygems"
require "optimist"
require "csv"

# Command-line options setup
OPTS = Optimist::options do
  banner <<-EOS
Run an experiment about the impact of the first_observation email.

Usage:

  rails runner tools/first_observation_experiment.rb

where [options] are:
EOS
  opt :cohort_data_path, "Path to the cohort data file.", type: :string, short: "-t"
end

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
            { term: { "taxon.id": 43_584 } },
            { term: { "taxon.id": 43_583 } }
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

headers = ["cohort", "user_id", "day0", "day1", "day2", "day3", "day4", "day5", "day6", "day7", "day8",
           "retention", "observer_appeal_intervention_group", "first_observation_intervention_group",
           "error_intervention_group", "captive_intervention_group"]

# Load existing user data or create a new CSV file with headers
raw_cohort_data = []
if File.exist?( OPTS.cohort_data_path )
  CSV.foreach( OPTS.cohort_data_path, headers: true ) do | row |
    raw_cohort_data << row.to_hash
  end
else
  CSV.open( OPTS.cohort_data_path, "w" ) do | csv |
    csv << headers
  end
end

cohort_data = {}
raw_cohort_data.each do | cohort |
  cohort_time = cohort["cohort"].to_s
  user_id = cohort["user_id"]
  cohort_data[cohort_time] ||= {}
  cohort_data[cohort_time][user_id.to_sym] = cohort.reject {| key, _ | ["cohort", "user_id"].include?( key ) }
end

cohorts = cohort_data.keys.uniq

current_day = Time.now.utc.end_of_day
window_start = current_day - 8.days

( ( current_day - window_start ) / ( 60 * 60 * 24 ) ).to_i.times do | i |
  current_day_to_iterate = window_start + i.days
  cohorts.each do | cohort |
    next unless cohort == current_day_to_iterate.to_date.to_s

    cohort_day = ( ( current_day - current_day_to_iterate ) / ( 60 * 60 * 24 ) ).to_i
    puts [cohort, cohort_day].join( " " )

    user_ids = cohort_data[cohort].keys.map {| key | key.to_s.to_i }
    obs_data = get_obs_span( current_day_to_iterate, current_day, user_ids )

    casual = obs_data.
      select {| _, v | ( v[:needs_id].nil? || v[:needs_id].zero? ) && ( v[:research].nil? || v[:research].zero? ) }.
      keys
    needs_id = obs_data.
      select {| _, v | v[:needs_id]&.positive? && ( v[:research].nil? || v[:research].zero? ) }.
      keys
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

# now sort out current day
start_time = Time.now
end_date = current_day
ad = SegmentationStatistic.generate_segmentation_int( end_date - 1.day, end_date, use_database: true )
active_0_new_users = ad.select {| _, v | v[:created_at].zero? }

obs_data = get_obs( end_date, active_0_new_users.keys )

casual = obs_data.
  select {| _, v | ( v[:needs_id].nil? || v[:needs_id].zero? ) && ( v[:research].nil? || v[:research].zero? ) }.
  keys
needs_id = obs_data.
  select {| _, v | ( !v[:needs_id].nil? && v[:needs_id].positive? ) && ( v[:research].nil? || v[:research].zero? ) }.
  keys
research = obs_data.select {| _, v | v[:research]&.positive? }.keys
no_obs = ( active_0_new_users.keys - casual - needs_id - research )
if casual.count.positive?
  captives = get_captives( end_date, casual )
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

# get retention if day 8
retention_cohort = ( current_day - 8.days ).to_date.to_s
if cohort_data[retention_cohort]
  retention_user_ids = cohort_data[retention_cohort].keys.map {| key | key.to_s.to_i }
  retention_users = ad.select {| k, _ | retention_user_ids.include? k }
  retention_users.each_key do | id |
    user_id = id.to_s.to_sym
    cohort_data[retention_cohort][user_id]["retention"] = true
  end
end

end_time = Time.now
duration = end_time - start_time
puts "Finished at #{end_time}"
puts "Time taken to run the script: #{duration} seconds"

# now do some interventions for the current day
# intervention 1: no_obs
cohort = current_day.to_date.to_s
subjects = cohort_data[cohort].select {| _, v | v["day0"] == "no_obs" }
subjects.each do | key, value |
  user = User.where( id: key.to_s.to_i ).first
  next unless user

  next unless user.locale =~ /en/

  next if user.email.nil? || !user.suspended_at.nil?

  geoip_response = INatAPIService.geoip_lookup( ip: user.last_ip )
  next unless geoip_response&.results && geoip_response.results.city.present? && geoip_response.results.ll.present?

  geoip_latitude, geoip_longitude = geoip_response.results.ll
  group = rand( 2 ).zero? ? "A" : "B"
  value["observer_appeal_intervention_group"] = group
  next unless group == "A"

  puts "sending...#{user.id}"
  Emailer.observer_appeal( user, latitude: geoip_latitude, longitude: geoip_longitude ).deliver_now
end

( 0..8 ).each do | d |
  cohort = ( current_day - ( d * 24 * 60 * 60 ) ).to_date.to_s
  slot = "day#{d}"
  prev_slots = ( 0...d ).map {| q | "day#{q}" }

  puts "#{cohort} #{slot}"
  next unless cohort_data[cohort]

  # intervention 2: error
  subjects = cohort_data[cohort].select do | _, v |
    v[slot] == "error" && prev_slots.all? do | prev_slot |
      ["no_obs", "captives", "needs_id"].include?( v[prev_slot] )
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
          any? {| field | quality_metric_observation_ids( [observation.id], field ).count == 1 }
        errors.concat(
          ["recent", "evidence", "location", "date"].
          select {| field | quality_metric_observation_ids( [observation.id], field ).count == 1 }.
          map {| field | error_key.fetch( field, field ) }
        )
      elsif quality_metric_observation_ids( [observation.id], "subject" ).count == 1
        errors << "single_species"
      end

    elsif !observation.appropriate?
      errors << "copyright"
    end

    next unless errors.count.positive?

    group = rand( 2 ).zero? ? "A" : "B"
    value["error_intervention_group"] = group
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
    value["captive_intervention_group"] = group

    next unless group == "A"

    puts "sending...#{user.id} #{observation.id}"
    Emailer.captive_observation( user, observation ).deliver_now
  end

  # intervention 4: research
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
    value["first_observation_intervention_group"] = group

    next unless group == "A"

    puts "sending...#{user.id}"
    Emailer.first_observation( user, observation ).deliver_now
  end
end

# Open the CSV file in write mode
CSV.open( OPTS.cohort_data_path, "w" ) do | csv |
  # Write the header row
  csv << headers

  # Iterate through cohort_data hash
  cohort_data.each do | cohort_date, users |
    users.each do | user_id, data |
      row = [cohort_date, user_id]
      headers[2..].each do | header |
        row << data.fetch( header, nil )
      end
      csv << row
    end
  end
end
