# frozen_string_literal: true

module DataPartnerLinkers
  class Eddmaps < DataPartnerLinkers::DataPartnerLinker
    # identifier for iNat on EDDMapS
    EDDMAPS_REPORTER_ID = 105_332
    PER_PAGE = 500

    def run
      start_time = Time.now
      new_count = 0
      old_count = 0
      page = 1

      while true
        url = "https://api.bugwoodcloud.org/v2/occurrence?" \
          "reporter=#{EDDMAPS_REPORTER_ID}&pagesize=#{PER_PAGE}&page=#{page}&paging=true&sort=objectid&sortorder=asc"
        logger.info "Fetching #{url}"
        response = JSON.parse( Net::HTTP.get( URI( url ) ) )
        records = response["data"]
        break if records.size.zero?

        observation_ids = []
        records.each do | record |
          observation_id = record["url"].to_s[%r{/(\d+)$}, 1]
          observation = Observation.find_by_id( observation_id )
          if observation.blank?
            logger.debug "\tobservation #{observation_id} doesn't exist, skipping..."
            next
          end
          href = "https://www.eddmaps.org/distribution/point.cfm?id=#{record['objectid']}"
          existing = ObservationLink.where( observation_id: observation_id, href: href ).first
          if existing
            existing.touch unless @opts[:debug]
            old_count += 1
            logger.debug "\tobservation link for obs #{observation.id} already exists, skipping"
          else
            ol = ObservationLink.new(
              observation: observation,
              href: href,
              href_name: @data_partner.name,
              rel: "alternate"
            )
            observation_ids << observation.id
            ol.save unless @opts[:debug]
            new_count += 1
            logger.debug "\tCreated #{ol}"
          end
        end
        if observation_ids.size.positive?
          logger.info "Re-indexing #{observation_ids.size} observations..."
          unless @opts[:debug]
            Observation.elastic_index!( ids: observation_ids, wait_for_index_refresh: true )
          end
        end
        page += 1
      end

      delete_scope = ObservationLink.
        where( href_name: @data_partner.name ).
        where( "updated_at < ?", start_time )
      delete_count = delete_scope.count
      logger.info "Deleting #{delete_count} ObservationLinks"
      return unless delete_count.positive? && !@opts[:debug]

      observation_ids = delete_scope.pluck( :observation_id )
      delete_scope.delete_all
      logger.info "Re-indexing observations with deleted ObservationLinks"
      Observation.elastic_index!( ids: observation_ids, wait_for_index_refresh: true )
    end
  end
end
