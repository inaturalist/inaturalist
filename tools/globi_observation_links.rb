require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Create ObservationLinks for observations that have been integrated into 
Globi.

Usage:

  rails runner tools/globi_observation_links.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :according_to, "Data provider name in GLoBI, defaults to inaturalist",
    type: :string,
    short: "-p",
    default: "globi:globalbioticinteractions/inaturalist"
end

start_time = Time.now
new_count = 0
old_count = 0
delete_count = 0
href_name = "GloBI"
according_to = opts.according_to
limit = 1000
skip = 0
logger = Logger.new( STDOUT )

while true do
  url = "https://api.globalbioticinteractions.org/interaction?accordingTo=#{according_to}&field=study_url&includeObservations=true&limit=#{limit}&skip=#{skip}"
  logger.info
  logger.info url
  logger.info
  data = JSON.parse( Net::HTTP.get( URI( url ) ) )
  records = data['data']
  break if records.size == 0
  observation_ids = []
  records.each do |record|
    observation_id = record[0].to_s[/\/(\d+)$/, 1]
    observation = Observation.find_by_id(observation_id)
    if observation.blank?
      logger.info "\tobservation #{observation_id} doesn't exist, skipping..."
      next
    end
    href = "http://www.globalbioticinteractions.org/?interactionType=interactsWith&accordingTo=#{UrlHelper.observation_url(observation_id)}"
    existing = ObservationLink.where(observation_id: observation_id, href: href).first
    if existing
      existing.touch unless opts[:debug]
      old_count += 1
      logger.info "\tobservation link for obs #{observation.id} already exists, skipping"
    else
      ol = ObservationLink.new(:observation => observation, :href => href, :href_name => href_name, :rel => "alternate")
      observation_ids << observation.id
      ol.save unless opts[:debug]
      new_count += 1
      logger.info "\tCreated #{ol}"
    end
  end
  if observation_ids.size > 0
    logger.info "Re-indexing #{observation_ids.size} observations..."
    Observation.elastic_index!( ids: observation_ids, wait_for_index_refresh: true ) unless opts[:debug]
  end
  skip += 1000
end

delete_scope = ObservationLink.where(href_name: href_name).where("updated_at < ?", start_time)
delete_count = delete_scope.count
logger.info "Deleting #{delete_count} ObservationLinks"
if !opts[:debug] && delete_count > 0
  observation_ids = delete_scope.pluck(:observation_id)
  delete_scope.delete_all
  logger.info "Re-indexing observations with deleted ObservationLinks"
  Observation.elastic_index!( ids: observation_ids, wait_for_index_refresh: true )
end

logger.info "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s"
