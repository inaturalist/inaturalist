# frozen_string_literal: true

require "rubygems"
require "optimist"

opts = Optimist.options do
  banner <<~DESC
    Create ObservationLinks for observations that have been integrated into#{' '}
    EDDMapS.

    Usage:

      rails runner tools/eddmaps_observation_links.rb

    where [options] are:
  DESC
  opt :debug, "Print debug statements", type: :boolean, short: "-d"
  opt :log_task_name, "Log with the specified task name", type: :string
end

if opts.log_task_name
  task_logger = TaskLogger.new( opts.log_task_name, nil, "sync" )
end

task_logger&.start

start_time = Time.now
new_count = 0
old_count = 0
href_name = "EDDMapS"
reporter = 105_332 # identifier for iNat on EDDMapS
limit = 500
page = 1

while true
  # url = "https://api.bugwood.org/rest/api/occurrence.json?includeonly=objectid,URL&reporter=#{reporter}&draw=1&length=#{limit}&start=#{start}"
  # The above no longer works; there's no new equivalent of the start param, so we might have to do it by date
  url = "https://api.bugwoodcloud.org/v2/occurrence?" \
    "reporter=#{reporter}&pagesize=#{limit}&page=#{page}&paging=true&sort=objectid&sortorder=asc"
  puts
  puts url
  puts
  response = JSON.parse( Net::HTTP.get( URI( url ) ) )
  records = response["data"]
  break if records.size.zero?

  observation_ids = []
  records.each do | record |
    observation_id = record["url"].to_s[%r{/(\d+)$}, 1]
    observation = Observation.find_by_id( observation_id )
    if observation.blank?
      puts "\tobservation #{observation_id} doesn't exist, skipping..."
      next
    end
    href = "https://www.eddmaps.org/distribution/point.cfm?id=#{record['objectid']}"
    existing = ObservationLink.where( observation_id: observation_id, href: href ).first
    if existing
      existing.touch unless opts[:debug]
      old_count += 1
      puts "\tobservation link for obs #{observation.id} already exists, skipping"
    else
      ol = ObservationLink.new( observation: observation, href: href, href_name: href_name, rel: "alternate" )
      observation_ids << observation.id
      ol.save unless opts[:debug]
      new_count += 1
      puts "\tCreated #{ol}"
    end
  end
  if observation_ids.size.positive?
    puts "Re-indexing #{observation_ids.size} observations..."
    Observation.elastic_index!( ids: observation_ids, wait_for_index_refresh: true ) unless opts[:debug]
  end
  page += 1
end

delete_scope = ObservationLink.where( href_name: href_name ).where( "updated_at < ?", start_time )
delete_count = delete_scope.count
puts "Deleting #{delete_count} ObservationLinks"
if !opts[:debug] && delete_count.positive?
  observation_ids = delete_scope.pluck( :observation_id )
  delete_scope.delete_all
  puts "Re-indexing observations with deleted ObservationLinks"
  Observation.elastic_index!( ids: observation_ids, wait_for_index_refresh: true )
end

puts "#{new_count} created, #{old_count} updated, #{delete_count} deleted in #{Time.now - start_time} s"

task_logger&.end
