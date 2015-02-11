require 'rubygems'
require 'trollop'

opts = Trollop::options do
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
    puts "\tCreated #{ol}"
  end
end

delete_count = ObservationLink.where(href_name: "Calflora").where("updated_at < ?", start_time).count
ObservationLink.delete_all(["href_name = 'Calflora' AND updated_at < ?", start_time]) unless opts[:debug]

puts "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s"
