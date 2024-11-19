require "rubygems"
require "optimist"
require "csv"

OPTS = Optimist::options do
  banner <<-EOS
Run an experiment about the impact of the observer_appeal email.

Usage:

  rails runner tools/observer_appeal_experiment.rb

where [options] are:
EOS
  opt :user_data_path, "Path to the user data file.", type: :string, short: "-t"
end

# Validate user_data_path option
unless OPTS.user_data_path
  puts "You must specify a user data path"
  exit( 1 )
end

# Load existing user data if the file exists
previous_user_set = {}
if File.exist?( OPTS.user_data_path )
  CSV.foreach( OPTS.user_data_path, headers: true ) do | row |
    previous_user_set[row["user_id"].to_i] = {
      user_id: row["user_id"],
      latitude: row["latitude"],
      longitude: row["longitude"],
      city: row["city"],
      group: row["group"],
      contact_date: row["contact_date"]
    }
  end
else
  # Create the file with headers if it doesn't exist
  CSV.open( OPTS.user_data_path, "w" ) do | csv |
    csv << ["user_id", "latitude", "longitude", "city", "group", "contact_date"] # Headers
  end
end

# Calculate the date range for querying users
current_day = Time.now
days_to_subtract = 7
one_week_ago = current_day - days_to_subtract.days
at_start_of_day = one_week_ago.beginning_of_day
at_end_of_day = one_week_ago.end_of_day

# Query users matching criteria
users = User.where(
  "locale LIKE ? AND created_at >= ? AND created_at <= ? AND observations_count = 0",
  "en%",
  at_start_of_day,
  at_end_of_day
)

# Collect user data for the experiment
users_set = {}
users.each do | user |
  next if previous_user_set[user.id]

  geoip_response = INatAPIService.geoip_lookup( ip: user.last_ip )
  next unless geoip_response&.results && geoip_response.results.city.present? && geoip_response.results.ll.present?

  geoip_latitude, geoip_longitude = geoip_response.results.ll
  group = rand( 2 ).zero? ? "A" : "B"
  users_set[user.id] = {
    user_id: user.id,
    latitude: geoip_latitude,
    longitude: geoip_longitude,
    city: geoip_response.results.city,
    group: group
  }
end

# Process users_set and update contact_date if necessary
users_set.each do | _, row |
  next unless row[:group] == "A"

  user = User.find_by( id: row[:user_id] )
  next unless user

  latitude = row[:latitude]
  longitude = row[:longitude]
  city = row[:city]

  # If email is sent successfully, update contact_date
  if Emailer.observer_appeal( user, latitude: latitude, longitude: longitude, city: city ).deliver_now
    row[:contact_date] = Time.now
  end
end

# Append the new user data to the CSV file
CSV.open( OPTS.user_data_path, "a" ) do | csv |
  users_set.each_value do | row |
    csv << [row[:user_id], row[:latitude], row[:longitude], row[:city], row[:group], row[:contact_date]]
  end
end
