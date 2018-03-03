require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS
Create ObservationLinks for observations that have been integrated into 
Globi.

Usage:

  rails runner tools/globi_observation_links.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :according_to, "Data provider name in GLoBI, defaults to inaturalist", type: :string, short: "-p", default: 'inaturalist'
end

start_time = Time.now
new_count = 0
old_count = 0
delete_count = 0
href_name = "GloBI"
according_to = opts.according_to
limit = 1000
skip = 0

while true do
  url = "https://api.globalbioticinteractions.org/interaction?accordingTo=#{according_to}&field=study_url&includeObservations=true&limit=#{limit}&skip=#{skip}"
  puts
  puts url
  puts
  data = JSON.parse(open(url).read)
  records = data['data']
  break if records.size == 0
  observation_ids = []
  records.each do |record|
    observation_id = record[0].to_s[/\/(\d+)$/, 1]
    observation = Observation.find_by_id(observation_id)
    if observation.blank?
      puts "\tobservation #{observation_id} doesn't exist, skipping..."
      next
    end
    href = "http://www.globalbioticinteractions.org/?interactionType=interactsWith&accordingTo=#{FakeView.observation_url(observation_id)}"
    existing = ObservationLink.where(observation_id: observation_id, href: href).first
    if existing
      existing.touch unless opts[:debug]
      old_count += 1
      puts "\tobservation link for obs #{observation.id} already exists, skipping"
    else
      ol = ObservationLink.new(:observation => observation, :href => href, :href_name => href_name, :rel => "alternate")
      observation_ids << observation.id
      ol.save unless opts[:debug]
      new_count += 1
      puts "\tCreated #{ol}"
    end
  end
  if observation_ids.size > 0
    puts "Re-indexing #{observation_ids.size} observations..."
    Observation.elastic_index!( ids: observation_ids ) unless opts[:debug]
  end
  skip += 1000
end

delete_scope = ObservationLink.where(href_name: href_name).where("updated_at < ?", start_time)
delete_count = delete_scope.count
puts "Deleting #{delete_count} ObservationLinks"
if !opts[:debug] && delete_count > 0
  observation_ids = delete_scope.pluck(:observation_id)
  delete_scope.delete_all
  puts "Re-indexing observations with deleted ObservationLinks"
  Observation.elastic_index!( ids: observation_ids )
end

puts "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s"
