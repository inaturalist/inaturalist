# frozen_string_literal: true

# Returns IDs of observations that have GBIF ObservationLinks in Postgres that
# are not represented in the observation's Elasticsearch document. Yields
# progress to stdout as it pages through the links
def gbif_es_drifted_observation_ids( batch_size: 1000 )
  drifted_ids = []
  checked_links = 0
  scope = ObservationLink.where( href_name: "GBIF" )
  total_links = scope.count
  puts "[#{Time.now}] Checking #{total_links} GBIF ObservationLinks against the #{Observation.index_name} index..."
  scope.select( :id, :observation_id, :href ).find_in_batches( batch_size: batch_size ) do | batch |
    links_by_observation_id = batch.group_by( &:observation_id )
    indexed_urls_by_observation_id = {}
    es_docs = Observation.elastic_mget( links_by_observation_id.keys, source: ["id", "outlinks"] )
    es_docs.each do | doc |
      indexed_urls_by_observation_id[doc["id"]] = ( doc["outlinks"] || [] ).map {| outlink | outlink["url"] }
    end
    links_by_observation_id.each do | observation_id, links |
      # observations missing from the index entirely count as drifted
      indexed_urls = indexed_urls_by_observation_id[observation_id] || []
      next if links.all? {| link | indexed_urls.include?( link.href ) }

      drifted_ids << observation_id
    end
    checked_links += batch.size
    percent_checked = ( checked_links / total_links.to_f * 100 ).round( 2 )
    puts "[#{Time.now}] Checked #{checked_links} of #{total_links} (#{percent_checked}%), " \
      "drifted so far: #{drifted_ids.size}"
  end
  drifted_ids
end

namespace :gbif_observation_links do
  desc "Report observations whose GBIF ObservationLinks are missing from their Elasticsearch docs"
  task assess_es_drift: :environment do
    drifted_ids = gbif_es_drifted_observation_ids
    puts "[#{Time.now}] #{drifted_ids.size} observations have GBIF ObservationLinks not represented in ES"
    puts drifted_ids.join( "," ) if drifted_ids.any? && ENV["PRINT_IDS"]
  end

  desc "Reindex observations whose GBIF ObservationLinks are missing from their Elasticsearch docs"
  task backfill_es_drift: :environment do
    drifted_ids = gbif_es_drifted_observation_ids
    puts "[#{Time.now}] #{drifted_ids.size} observations have GBIF ObservationLinks not represented in ES"
    if drifted_ids.empty?
      puts "[#{Time.now}] Nothing to reindex"
      next
    end
    puts "[#{Time.now}] Queueing delayed jobs to reindex #{drifted_ids.size} observations..."
    Observation.elastic_index!( ids: drifted_ids, delay: true, run_at: 1.minute.from_now )
    puts "[#{Time.now}] Done queueing. Indexing will continue in delayed jobs"
  end
end
