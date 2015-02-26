# Loads a bunch of dummy observations, random users, taxa, and locations.  Run
# with script/runner

if Rails.env == 'production'
  puts "Dude, you should NOT be running this in production"
  exit
end

QUIET = false
EARLIEST_TIME = Time.parse('2007-01-01')
LATEST_TIME = Time.now
count = 0
taxon_count = Taxon.count
user_count = User.count
num_obs = (ARGV[0] || 100).to_i

num_obs.times do
  taxon = Taxon.offset(rand(taxon_count)).first
  time = EARLIEST_TIME + rand(LATEST_TIME - EARLIEST_TIME)
  user = User.offset(rand(user_count)).first
  next unless user.active?
  obs = Observation.new(
    :user => user, 
    :taxon => taxon, 
    :species_guess => taxon.name,
    :observed_on_string => time.to_date.to_s,
    # :time_observed_at => time,
    # Create observations in the Bay Area
    # :latitude => rand + 37, 
    # :longitude => (rand + 122)*-1)
    # Create obs in the northern part of the western hemisphere
    :latitude => rand * 80,
    :longitude => rand * -170)
  if obs.save
    puts "Created #{obs}" unless QUIET
    count += 1
  else
    puts "Invalid!, Skipping observation for user #{obs.user}: #{obs.errors.full_messages.to_sentence}"
  end
end

puts "Created #{count} observations"

# Observation.all.each {|o| o.destroy}
