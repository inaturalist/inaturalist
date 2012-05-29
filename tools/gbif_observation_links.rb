require 'rubygems'
require 'trollop'

opts = Trollop::options do
    banner <<-EOS


where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
end

start_time = Time.now
new_count = 0
old_count = 0
delete_count = 0
startindex = 0
maxresults = 100
while true do
  url = "http://data.gbif.org/ws/rest/occurrence/list?startindex=#{startindex}&maxresults=#{maxresults}&institutioncode=iNaturalist&format=brief"
  puts url
  xml = Nokogiri::XML.parse(open(url).read)
  occurrences = xml.search('//to:TaxonOccurrence')
  break if occurrences.size == 0
  occurrences.each do |to|
    observation_id = to.xpath('to:catalogNumber').first.try(:inner_text)
    gbif_id = to[:gbifKey]
    puts gbif_id
    observation = Observation.find_by_id(observation_id)
    if observation.blank?
      puts "\tobservation #{observation_id} doesn't exist, skipping..."
      next
    end
    href = "http://data.gbif.org/occurrences/#{gbif_id}"
    existing = ObservationLink.first(:conditions => {:observation_id => observation_id, :href => href})
    if existing
      existing.touch unless opts[:debug]
      old_count += 1
      puts "\tobservation link already exists, skipping"
    else
      ol = ObservationLink.new(:observation => observation, :href => href, :href_name => "GBIF", :rel => "alternate")
      ol.save unless opts[:debug]
      new_count += 1
      puts "\tCreated #{ol}"
    end
  end
  
  startindex += maxresults
  puts
end

delete_count = ObservationLink.count(:conditions => ["href_name = 'GBIF' AND updated_at < ?", start_time])
ObservationLink.delete_all(["href_name = 'GBIF' AND updated_at < ?", start_time]) unless opts[:debug]

puts "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s"
