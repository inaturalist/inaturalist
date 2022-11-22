# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Import conservation statuses from CSV made using the template at
    https://docs.google.com/spreadsheets/d/1OxlVBw4xifdFugMq42gbMS8IDFiliYcC5imc0sUSWn8

    Usage:

      rails runner tools/import_conservation_statuses.rb PATH_TO_CSV

    where [options] are:
  BANNER
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :dry, "Dry run, don't actually change anything", type: :boolean
  opt :place_id, "Assign statuses to this place", type: :integer, short: "-p"
  opt :user_id, "User ID of user who is adding these statuses", type: :integer, short: "-u"
end

HEADERS = %w(
  taxon_name
  status
  authority
  iucn
  description
  place_id
  url
  geoprivacy
  user
  taxon_id
).freeze
REQUIRED = %w(
  taxon_name
  status
  authority
  iucn
).freeze

csv_path = ARGV[0]
Optimist.die "You must a CSV file to import" if csv_path.blank?
Optimist.die "#{csv_path} does not exist" unless File.exist?( csv_path )
unless opts.place_id.blank?
  if ( @place = Place.find( opts.place_id ) )
    puts "Found place: #{@place}"
  else
    Optimist.die "Couldn't find place: #{OPTS.place_id}"
  end
end
unless opts.user_id.blank?
  @user = User.find_by_id( opts.user_id )
  @user ||= User.find_by_login( opts.user_id )
  if @user
    puts "Found user: #{@user}"
  else
    Optimist.die "Couldn't find user: #{OPTS.user_id}"
  end
end

start = Time.now
created = []
skipped = []

CSV.foreach( csv_path, headers: HEADERS ) do | row |
  identifier = [row["taxon_name"], row["status"], row["place_id"]].join( " | " )
  puts identifier
  blank_column = catch :required_missing do
    REQUIRED.each {| h | throw :required_missing, h if row[h].blank? }
    nil
  end
  if blank_column
    puts "#{blank_column} cannot be blank, skipping..."
    next
  end
  taxon = row["taxon_id"].blank? ? nil : Taxon.find_by_id( row["taxon_id"] )
  taxon ||= Taxon.single_taxon_for_name( row["taxon_name"] )
  unless taxon
    puts "\tCouldn't find taxon for '#{row['taxon_name']}', skipping..."
    skipped << identifier
    next
  end
  place = @place
  if place.blank? && !row["place_id"].blank?
    place = begin
      Place.find( row["place_id"] )
    rescue StandardError
      nil
    end
    if place.blank?
      puts "\tPlace #{row['place_id']} specified but not found, skipping..."
      skipped << identifier
      next
    end
  end
  iucn = if place && row["iucn"].to_s.strip.parameterize.underscore == "regionally_extinct"
    Taxon::IUCN_STATUS_VALUES["extinct"]
  else
    Taxon::IUCN_STATUS_VALUES[row["iucn"].to_s.strip.parameterize.underscore]
  end
  iucn ||= Taxon::IUCN_CODE_VALUES[row["iucn"].to_s.strip.upcase]
  unless iucn
    puts "\t#{row['iucn']} is not a valid IUCN status, skipping..."
    skipped << identifier
    next
  end
  user = @user
  if user.blank? && !row["user"].blank?
    user = User.find_by_login( row["user"] )
    user ||= User.find_by_id( row["user"] )
    if user.blank?
      puts "\tUser #{row['user']} specified but no matching user found, skipping..."
      skipped << identifier
      next
    end
  end
  unless row["geoprivacy"].blank?
    geoprivacies = [Observation::OPEN, Observation::OBSCURED, Observation::PRIVATE]
    unless geoprivacies.include?( row["geoprivacy"].to_s.downcase.underscore )
      puts "\tGeoprivacy '#{row['geoprivacy']}' was not recognized, skipping..."
      skipped << identifier
      next
    end
  end
  cs = ConservationStatus.new(
    taxon: taxon,
    place: place,
    status: row["status"],
    iucn: iucn,
    authority: row["authority"],
    description: row["description"],
    url: row["url"],
    geoprivacy: row["geoprivacy"],
    user: user
  )
  if cs.valid?
    cs.save unless opts.dry
    puts "\tCreated #{cs}"
    created << identifier
  else
    puts "\tConservation status #{cs} was not valid: #{cs.errors.full_messages.to_sentence}"
    skipped << identifier
  end
end

puts "Created:"
created.each do | c |
  puts c
end

puts
puts "Skipped:"
skipped.each do | c |
  puts c
end

puts
puts "#{created.size} created, #{skipped.size} skipped in #{Time.now - start}s"
puts
