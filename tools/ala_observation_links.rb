require "rubygems"
require "optimist"

@opts = Optimist::options do
    banner <<-EOS
Create ObservationLinks for observations that have been integrated into 
the Atlas of Living Australia.

Usage:

  rails runner tools/ala_observation_links.rb [DATA RESOURCE UID]

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
end

data_resource_uid = ARGV[0]
Optimist::die "You must specify a data resource UID" if data_resource_uid.blank?

start_time = Time.now
new_count = 0
old_count = 0
delete_count = 0
startindex = 0
maxresults = 100
href_name = "Atlas of Living Australia"
obs_ids_to_index = []
while true do
  url = "http://biocache.ala.org.au/ws/webportal/occurrences?facet=off&fq=data_resource_uid:#{data_resource_uid}&pageSize=#{maxresults}&startIndex=#{startindex}"
  puts url
  data = JSON.parse( RestClient.get( url, { "User-Agent" => Site.default.name } ).body )
  occurrences = data['occurrences']
  break if occurrences.size == 0
  occurrences.each do |to|
    observation_id = to['occurrenceID'].to_s.split('/').last
    remote_id = to['uuid']
    puts remote_id
    observation = Observation.find_by_id(observation_id)
    if observation.blank?
      puts "\tobservation #{observation_id} doesn't exist, skipping..."
      next
    end
    href = "http://biocache.ala.org.au/occurrences/#{remote_id}"
    existing = ObservationLink.where(:observation_id => observation_id, :href => href).first
    if existing
      existing.touch unless @opts[:debug]
      old_count += 1
      puts "\tobservation link already exists for observation #{observation_id}, skipping"
    else
      ol = ObservationLink.new(:observation => observation, :href => href, :href_name => href_name, :rel => "alternate")
      ol.save unless @opts[:debug]
      new_count += 1
      obs_ids_to_index << observation.id
      puts "\tCreated #{ol}"
    end
  end
  
  startindex += maxresults
  puts
end

links_to_delete_scope = ObservationLink.where(href_name: href_name).where("updated_at < ?", start_time)
delete_count = links_to_delete_scope.count
obs_ids_to_index += links_to_delete_scope.pluck(:observation_id)
links_to_delete_scope.delete_all unless @opts[:debug]

puts
puts "Re-indexing #{obs_ids_to_index.size} observations..."
obs_ids_to_index = obs_ids_to_index.compact.uniq
obs_ids_to_index.in_groups_of( 500 ) do |group|
  print '.'
  Observation.elastic_index!( ids: group.compact, wait_for_index_refresh: true )
end
puts

puts
puts "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s"
