# frozen_string_literal: true

# Finds observations that have GBIF ObservationLinks in Postgres that are not
# represented in the observation's Elasticsearch document. Yields progress to
# stdout as it pages through the links. When given a block, yields each scan
# batch's drifted observation IDs as they are found (and returns an empty
# array) so callers can process millions of drifted IDs without holding them
# all in memory. Without a block, accumulates and returns all drifted IDs.
def gbif_es_drifted_observation_ids( batch_size: 1000 )
  drifted_ids = []
  drifted_count = 0
  checked_links = 0
  scope = ObservationLink.where( href_name: "GBIF" )
  total_links = scope.count
  puts "[#{Time.now}] Checking #{total_links} GBIF ObservationLinks against the #{Observation.index_name} index..."
  scope.select( :id, :observation_id, :href ).find_in_batches( batch_size: batch_size ) do | batch |
    batch_drifted_ids = []
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

      batch_drifted_ids << observation_id
    end
    drifted_count += batch_drifted_ids.size
    if block_given?
      yield batch_drifted_ids if batch_drifted_ids.any?
    else
      drifted_ids.concat( batch_drifted_ids )
    end
    checked_links += batch.size
    percent_checked = ( checked_links / total_links.to_f * 100 ).round( 2 )
    puts "[#{Time.now}] Checked #{checked_links} of #{total_links} (#{percent_checked}%), " \
      "drifted so far: #{drifted_count}"
  end
  drifted_ids
end

def queue_index_job( ids )
  Observation.elastic_index!( ids: ids, delay: true, run_at: 1.minute.from_now )
  @queued_count += ids.size
  puts "[#{Time.now}] Queued delayed jobs to reindex #{@queued_count} observations so far..."
end

namespace :gbif_observation_links do
  desc "Report observations whose GBIF ObservationLinks are missing from their Elasticsearch docs"
  task assess_es_drift: :environment do
    drifted_ids = gbif_es_drifted_observation_ids
    puts "[#{Time.now}] #{drifted_ids.size} observations have GBIF ObservationLinks not represented in ES"
    puts drifted_ids.join( "," ) if drifted_ids.any? && ENV["PRINT_IDS"]
  end

  desc "Reindex observations whose GBIF ObservationLinks are missing from their Elasticsearch docs"
  task :backfill_es_drift, [:index_batch_size] => :environment do | _t, args |
    # Queue indexing jobs in fixed-size batches as drifted IDs are found so a
    # large drift never queues one delayed job with millions of IDs in it
    @queued_count = 0
    index_batch_size = ( args.index_batch_size || 1000 ).to_i
    index_queue = []

    gbif_es_drifted_observation_ids do | drifted_ids |
      # Each batch is of observations yields to this block.
      # We append to the queue and immediately shift from it
      # to keep the index_queue array from growing too large.
      index_queue.concat( drifted_ids )
      while index_queue.size >= index_batch_size
        queue_index_job( index_queue.shift( index_batch_size ) )
      end
    end
    queue_index_job( index_queue ) if index_queue.any?
    puts "[#{Time.now}] #{@queued_count} observations have GBIF ObservationLinks not represented in ES"
    if @queued_count.zero?
      puts "[#{Time.now}] Nothing to reindex"
      next
    end
    puts "[#{Time.now}] Done queueing. Indexing will continue in delayed jobs"
  end
end
