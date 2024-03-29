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
  opt :user_data_path, "Path to the user data file.", type: :string, short: "-t"
end

# Validate user_data_path option
unless OPTS.user_data_path
  puts "You must specify a user data path"
  exit( 1 )
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

# Load existing user data or create a new CSV file with headers
previous_user_set = {}
if File.exist?( OPTS.user_data_path )
  CSV.foreach( OPTS.user_data_path, headers: true ) do | row |
    previous_user_set[row["user_id"].to_i] = row.to_hash
  end
else
  CSV.open( OPTS.user_data_path, "w" ) do | csv |
    csv << ["user_id", "observation_id", "latitude", "longitude", "city", "set", "group", "errors", "contact_date"]
  end
end

# Fetching users' IDs and excluding users that have more than one observation
start_time = 1.day.ago.utc
end_time = Time.now.utc
user_ids = Observation.elastic_search(
  size: 0,
  filters: [
    { range: { created_at: { gte: start_time, lte: end_time } } }
  ],
  aggregate: {
    distinct_users: {
      terms: {
        field: "user.id",
        size: 200_000
      }
    }
  }
).response.aggregations.distinct_users.buckets.map {| b | b["key"] }

# Query users matching criteria
users = User.where( id: user_ids ).where( "locale LIKE ? AND observations_count = 1", "en%" )

# Collect user data for the experiment
users_set = {}
users.each do | user |
  next if previous_user_set[user.id]

  observation = Observation.find_by( user_id: user.id )
  next unless observation &&
    ( geoip_response = INatAPIService.geoip_lookup( ip: user.last_ip ) )&.results&.city && geoip_response.results.ll

  group = rand( 2 ).zero? ? "A" : "B"
  errors = []

  if observation.research_grade_candidate?
    set = observation.quality_grade == "research" ? "research" : "needs_id"
  elsif !observation.georeferenced? || !observation.observed_on? || ( !observation.photos? && !observation.sounds? ) ||
      observation.human? || !observation.quality_metrics_pass?
    if !observation.georeferenced? || !observation.observed_on? || ( !observation.photos? && !observation.sounds? )
      set = "error_missing"
      errors.concat(
        ["georeferenced", "observed_on"].reject {| error | observation.public_send( "#{error}?" ) } +
        ( observation.photos? || observation.sounds? ? [] : ["media"] )
      )
    elsif ["recent", "evidence", "location", "date"].
        any? {| error | quality_metric_observation_ids( [observation.id], error ).count == 1 }
      set = "error_dqa"
      errors.concat(
        ["recent", "evidence", "location", "date"].
        select {| error | quality_metric_observation_ids( [observation.id], error ).count == 1 }
      )
    elsif quality_metric_observation_ids( [observation.id], "subject" ).count == 1
      set = "error_subject"
    elsif observation.human? || quality_metric_observation_ids( [observation.id], "wild" ).count == 1
      set = "captive_or_human"
    end
  end

  users_set[user.id] = {
    user_id: user.id,
    observation_id: observation.id,
    latitude: geoip_response.results.ll[0],
    longitude: geoip_response.results.ll[1],
    city: geoip_response.results.city,
    group: group,
    errors: errors,
    set: set
  }
end

# Process users_set and update contact_date if necessary
users_set.each do | _, row |
  next unless row[:group] == "A"

  user = User.find_by( id: row[:user_id] )
  next unless user

  observation = Observation.find_by( id: row[:observation_id] )
  next unless observation

  latitude = row[:latitude]
  longitude = row[:longitude]
  city = row[:city]
  set = row[:set]
  errors = row[:errors]

  # If email is sent successfully, update contact_date
  row[:contact_date] = Time.now if Emailer.first_observation(
    user, observation,
    latitude: latitude,
    longitude: longitude,
    city: city,
    set: set,
    errors: errors
  ).deliver_now
end

# Append the new user data to the CSV file
CSV.open( OPTS.user_data_path, "a" ) do | csv |
  users_set.each_value do | row |
    csv << [
      row[:user_id],
      row[:observation_id],
      row[:latitude],
      row[:longitude],
      row[:city],
      row[:set],
      row[:group],
      row[:errors].join( ":" ),
      row[:contact_date]
    ]
  end
end
