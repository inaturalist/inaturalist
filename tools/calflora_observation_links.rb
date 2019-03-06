require "rubygems"
require "optimist"

opts = Optimist::options do
    banner <<-EOS
Create ObservationLinks for observations that have been integrated into 
Calflora.

Usage:

  rails runner tools/calflora_observation_links.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
end

start_time = Time.now
new_count = 0
old_count = 0
delete_count = 0
# startindex = 0
# maxresults = 100
obs_ids_to_index = []

url = "http://www.calflora.org/app/download?order=seq_num&wint=noc&format=Bar&cols=ID&org=iNaturalist"
open(url).read.split("\n").each do |line|
  line = line.strip
  next if line =~ /^ID/
  observation_id = line.split(':').last
  calflora_id = line
  puts calflora_id
  observation = Observation.find_by_id(observation_id)
  if observation.blank?
    puts "\tobservation #{observation_id} doesn't exist, skipping..."
    next
  end
  href = "http://www.calflora.org/cgi-bin/noccdetail.cgi?seq_num=#{calflora_id}"
  existing = ObservationLink.where(observation_id: observation_id, href: href).first
  if existing
    existing.touch unless opts[:debug]
    old_count += 1
    puts "\tobservation link already exists, skipping"
  else
    ol = ObservationLink.new(:observation => observation, :href => href, :href_name => "Calflora", :rel => "alternate")
    ol.save unless opts[:debug]
    new_count += 1
    obs_ids_to_index << observation.id
    puts "\tCreated #{ol}"
  end
end

links_to_delete_scope = ObservationLink.where("href_name = 'Calflora' AND updated_at < ?", start_time)
delete_count = links_to_delete_scope.count
obs_ids_to_index += links_to_delete_scope.pluck(:observation_id)
links_to_delete_scope.delete_all unless opts[:debug]

puts
puts "Re-indexing #{obs_ids_to_index.size} observations..."
obs_ids_to_index = obs_ids_to_index.compact.uniq
obs_ids_to_index.in_groups_of( 500 ) do |group|
  print '.'
  Observation.elastic_index!( ids: group.compact )
end
puts

puts
puts "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s"
