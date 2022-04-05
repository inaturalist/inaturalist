# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~BANNER
    Import conservation statuses from CSV made using the template at ???

    This is a lot like import_conservation_statuses.rb except it supports full CRUD,
    not just creation of statuses. It's mostly meant for working with network
    partners who want control over conservation statuses in their country.

    Usage:

      rails runner tools/import_conservation_statuses_for_partner.rb PATH_TO_CSV

    where [options] are:
  BANNER
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
).freeze
REQUIRED = %w(
  action
).freeze

csv_path = ARGV[0]
Optimist.die "You must a CSV file to import" if csv_path.blank?
Optimist.die "#{csv_path} does not exist" unless File.exist?( csv_path )

start = Time.now
created = []
updated = []
deleted = []
skipped = []

logger = Logger.new( $stdout )
logger.level = case opts.log_level
when "unknown" then Logger::UNKNOWN
when "fatal" then Logger::FATAL
when "error" then Logger::ERROR
when "warn" then Logger::WARN
when "debug" then Logger::DEBUG
else
  Logger::INFO
end

CSV.foreach( csv_path, headers: HEADERS ) do | row |
  next if row["action"] == "action"

  identifier = %w(action taxon_name id place_id status iucn_equivalent).map {| a | row[a] }.join( "-" )
  logger.info identifier
  blank_column = catch :required_missing do
    REQUIRED.each {| h | throw :required_missing, h if row[h].blank? }
    nil
  end
  if blank_column
    logger.error "#{blank_column} cannot be blank, skipping..."
    skipped << identifier
    next
  end
  taxon = Taxon.find_by_id( row["taxon_id"] ) unless row["taxon_id"].blank?
  unless taxon
    logger.info "#{identifier}: Couldn't find taxon for '#{row['taxon_id']}', " \
      "trying to find the taxon by the name '#{row['taxon_name']}"
    if row["taxon_name"].blank?
      logger.error "#{identifier}: No name specified, skipping..."
      skipped << identifier
      next
    end
    unless ( taxon = Taxon.single_taxon_for_name( row["taxon_name"] ) )
      logger.error "#{identifier}: Couldn't find taxon for '#{row['taxon_name']}', skipping..."
      skipped << identifier
      next
    end
  end
  place = begin
    Place.find( row["place_id"] )
  rescue StandardError
    nil
  end
  if place.blank? && !row["place_id"].blank?
    logger.error "#{identifier}: Place #{row['place_id']} specified but not found, skipping..."
    skipped << identifier
    next
  end
  cs = ConservationStatus.find_by_id( row["id"] ) unless row["id"].blank?
  cs ||= taxon.conservation_statuses.where(
    place_id: place,
    authority: row["authority"]
  ).first
  if row["action"] == "REMOVE"
    if cs
      cs.destroy
      deleted << identifier
      logger.debug "#{identifier}: Deleted #{identifier}"
    end
    next
  end
  iucn_equivalent = row["iucn_equivalent"].to_s.gsub( /\(.*\)/, "" ).strip.parameterize.underscore
  iucn = Taxon::IUCN_STATUS_VALUES[iucn_equivalent]
  iucn ||= if row["iucn_equivalent"].to_s.size.positive? &&
      Taxon::IUCN_STATUS_VALUES.values.include?( row["iucn_equivalent"].to_i )
    row["iucn_equivalent"].to_i
  end
  if iucn.nil? && !row["iucn_equivalent"].blank?
    logger.error "#{identifier}: #{row['iucn_equivalent']} is not a valid IUCN status, skipping..."
    skipped << identifier
    next
  end
  user = unless row["username"].blank?
    username = row["username"].strip
    user = User.find_by_login( username )
    user ||= User.find_by_id( username )
    if user.blank?
      logger.error "#{identifier}: User #{username} specified but no matching user found, skipping..."
      skipped << identifier
      next
    end
    user
  end
  cs ||= ConservationStatus.new( user: user, taxon: taxon, place: place )
  %w(status authority url geoprivacy).each do | a |
    cs.send( "#{a}=", row[a] ) unless row[a].blank?
  end
  cs.iucn = iucn unless iucn.blank?
  cs.updater = user if cs.changed?
  if cs.valid?
    cs.save! unless opts.dry
    if cs.id_previously_changed? || cs.new_record?
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
logger.info "#{created.size} created, #{deleted.size} deleted, " \
  "#{updated.size} updated, #{skipped.size} skipped in #{Time.now - start}s"
logger.info
