require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Import conservation statuses from CSV made using the template at ???

This is a lot like import_conservation_statuses.rb except it supports full CRUD,
not just creation of statuses. It's mostly meant for working with network
partners who want control over conservation statuses in their country.

Usage:

  rails runner tools/import_conservation_statuses_for_partner.rb PATH_TO_CSV

where [options] are:
EOS
  opt :dry, "Dry run, don't actually change anything", type: :boolean, short: "-d"
  opt :log_level, "Logger level", type: :string, short: "-l"
end

HEADERS = %w(
  action
  taxon_name
  id
  taxon_id
  status
  iucn_equivalent
  authority
  url
  geoprivacy
  place_id
  username
)
REQUIRED = %w(
  action
  taxon_id
)

csv_path = ARGV[0]
Optimist::die "You must a CSV file to import" if csv_path.blank?
Optimist::die "#{csv_path} does not exist" unless File.exists?( csv_path )

start = Time.now
created = []
updated = []
deleted = []
skipped = []

logger = Logger.new( STDOUT )
logger.level = case opts.log_level
when "unknown" then Logger::UNKNOWN
when "fatal" then Logger::FATAL
when "error" then Logger::ERROR
when "warn" then Logger::WARN
when "debug" then Logger::DEBUG
else
  Logger::INFO
end

CSV.foreach( csv_path, headers: HEADERS ) do |row|
  next if row["action"] == "action"
  identifier = %w(action taxon_name id place_id status iucn).map {|a| row[a] }.join( "-" )
  logger.info identifier
  blank_column = catch :required_missing do
    REQUIRED.each {|h| throw :required_missing, h if row[h].blank? }
    nil
  end
  if blank_column
    logger.error "#{blank_column} cannot be blank, skipping..."
    skipped << identifier
    next
  end
  taxon = Taxon.find_by_id( row["taxon_id"] )
  unless taxon
    logger.error "#{identifier}: Couldn't find taxon for '#{row["taxon_id"]}', skipping..."
    skipped << identifier
    next
  end
  place = Place.find( row["place_id"] ) rescue nil
  if place.blank? && !row["place_id"].blank?
    logger.error "#{identifier}: Place #{row["place_id"]} specified but not found, skipping..."
    skipped << identifier
    next
  end
  iucn = Taxon::IUCN_STATUS_VALUES[row["iucn"].to_s.parameterize.underscore]
  if iucn.blank? && !row["iucn"].blank?
    logger.error "#{identifier}: #{row["iucn"]} is not a valid IUCN status, skipping..."
    next
  end
  user = if !row["username"].blank?
    user = User.find_by_login( row["username"] )
    user ||= User.find_by_id( row["username"] )
    if user.blank?
      logger.error "#{identifier}: User #{row["username"]} specified but no matching user found, skipping..."
      skipped << identifier
      next
    end
    user
  end
  cs = ConservationStatus.find_by_id( row["id"] ) unless row["id"].blank?
  cs ||= taxon.conservation_statuses.where(
    place_id: place,
    status: row["status"],
    authority: row["authority"]
  ).first
  if row["action"] === "REMOVE"
    if cs
      cs.destroy
      deleted << identifier
      logger.debug "#{identifier}: Deleted #{identifier}"
    end
    next
  elsif row["action"] === "UPDATE" && !cs
    logger.error "#{identifier}: Conservation status does not exist, skipping..."
    skipped << identifier
    next
  end
  cs ||= ConservationStatus.new( user: user, taxon: taxon, place: place )
  %w(status authority url geoprivacy).each do |a|
    cs.send( "#{a}=", row[a] ) unless row[a].blank?
  end
  cs.iucn = iucn unless iucn.blank?
  if cs.valid?
    cs.save! unless opts.dry
    if cs.new_record?
      logger.debug "#{identifier}: Created #{cs}"
      created << identifier
    else
      logger.debug "#{identifier}: Updated #{cs}"
      updated << identifier
    end
  else
    logger.error "#{identifier}: Conservation status #{cs} was not valid: #{cs.errors.full_messages.to_sentence}"
    skipped << identifier
  end
end

logger.info
logger.info "#{created.size} created, #{deleted.size} deleted, #{updated.size} updated, #{skipped.size} skipped in #{Time.now - start}s"
logger.info
