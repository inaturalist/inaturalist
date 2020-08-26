module DataPartnerLinkers
  class MarylandBiodiversityProject < DataPartnerLinker
    def run
      url = "https://www.marylandbiodiversity.com/services/iNatMBPIDMap.php"
      page = 1
      start_time = Time.now
      obs_ids_to_index = []
      per_page = 500
      new_count = 0
      old_count = 0
      while true
        logger.info "Requesting #{url}, page: #{page}"
        resp = RestClient.get( url, params: { page: page, per_page: per_page } )
        json = JSON.parse( resp )
        break if json.size == 0
        obs_ids = json.map{|r| r["inat_id"] }
        existing_observation_links = ObservationLink.where(
          observation_id: obs_ids,
          href_name: @data_partner.name
        ).to_a
        observations = Observation.page_of_results( id: obs_ids, per_page: per_page )
        logger.debug "#{obs_ids.size} obs IDs in MBP batch #{page} starting with #{obs_ids.first}"
        logger.debug "#{existing_observation_links.size} existing links"
        logger.debug "#{observations.size} obs extant"
        json.each do |row|
          partner_record_id = row["mbp_id"]
          observation_id = row["inat_id"]
          href = "https://www.marylandbiodiversity.com/record/#{partner_record_id}"
          # existing = ObservationLink.where( observation_id: observation_id, href: href ).first
          observation = observations.detect{|o| o.id == observation_id.to_i }
          if existing = existing_observation_links.detect{|ol| ol.href == href }
            existing.touch unless @opts[:debug]
            old_count += 1
            # logger.debug "\tobservation link already exists, skipping"
            if observation && observation.last_indexed_at < existing.created_at
              obs_ids_to_index << observation.id
            end
          elsif observation
            ol = ObservationLink.new(
              observation: observation,
              href: href,
              href_name: @data_partner.name,
              rel: "alternate"
            )
            ol.save unless @opts[:debug]
            new_count += 1
            obs_ids_to_index << observation.id
            logger.debug "\tCreated #{ol}"
          end
        end
        page += 1
        sleep 5
      end
      links_to_delete_scope = ObservationLink.where( "href_name = ? AND updated_at < ?", @data_partner.name, start_time )
      delete_count = links_to_delete_scope.count
      obs_ids_to_index += links_to_delete_scope.pluck(:observation_id)
      logger.info "Deleting #{delete_count} links..."
      links_to_delete_scope.delete_all unless @opts[:debug]
      logger.info "Re-indexing #{obs_ids_to_index.size} observations..."
      obs_ids_to_index = obs_ids_to_index.compact.uniq
      obs_ids_to_index_groups = obs_ids_to_index.in_groups_of( 500 )
      obs_ids_to_index_groups.each_with_index do |group,i|
        logger.info "Indexing obs group #{i} / #{obs_ids_to_index_groups.size}"
        Observation.elastic_index!( ids: group.compact )
      end
      logger.info ""
      logger.info "MarylandBiodiversityProject created #{new_count} new links, #{old_count} existing, #{delete_count} deleted, #{obs_ids_to_index.size} obs reindexed"
      logger.info ""
    end
  end
end
