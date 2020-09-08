module DataPartnerLinkers
  class Calflora < DataPartnerLinkers::DataPartnerLinker

    # This is the maximum number of lines Calflora will return in a download. If
    # we get a response this size or bigger, we need to partition the data
    # requesting to get smaller responses so we don't miss anything
    MAX_DOWNLOAD_LINES = 50000

    def run
      @obs_ids_to_index = []
      @new_count = 0
      @old_count = 0
      start_time = Time.now
      partition_data  
      links_to_delete_scope = ObservationLink.where( "href_name = ? AND updated_at < ?", @data_partner.name, start_time )
      delete_count = links_to_delete_scope.count
      @obs_ids_to_index += links_to_delete_scope.pluck(:observation_id)
      @obs_ids_to_index = @obs_ids_to_index.uniq.compact
      # TODO extract link deletion into a parent class method, b/c all linkers need to do this
      logger.info "Deleting #{delete_count} links..."
      links_to_delete_scope.delete_all unless @opts[:debug]
      # TODO extract obs indexing so a) each linker doesn't have to do this, and
      # b) we can minimize the obs we need to index when syncing links for
      # multiple linkers
      logger.info "Re-indexing #{@obs_ids_to_index.size} observations..."
      obs_ids_to_index_groups = @obs_ids_to_index.in_groups_of( 500 )
      obs_ids_to_index_groups.each_with_index do |group,i|
        logger.info "Indexing obs group #{i} / #{obs_ids_to_index_groups.size}"
        Observation.elastic_index!( ids: group.compact )
      end
      logger.info ""
      logger.info "#{self.class.name} created #{@new_count} new links, " +
        "#{@old_count} existing, #{delete_count} deleted, " +
        "#{@obs_ids_to_index.size} obs reindexed in #{Time.now - start_time}s"
      logger.info ""
    end

    def get_calflora_rows( after = nil, before = nil )
      params = {
        format: "Bar",
        cols: "ID,Source",
        org: "iNaturalist",
        dateAfter: after.to_s,
        dateBefore: before.to_s,
        wint: "r"
      }
      logger.info "Getting Calflora iNat obs after #{after} and before #{before}"
      resp = RestClient.get( "https://www.calflora.org/app/download", params: params )
      return [] if resp.blank?
      resp.to_s.split( /\r?\n/ )[1..-1].map{|row| row.split( "|" ) }
    end

    def partition_data(after = Date.parse("1900-01-01"), before=Date.today)
      rows = get_calflora_rows( after, before )
      if rows.size >= MAX_DOWNLOAD_LINES
        split = before - ( ( before - after ) / 2 )
        partition_data( after, split )
        partition_data( split, before )
      else
        process_rows( rows )
      end
    end

    def process_rows( rows )
      logger.info "Processing #{rows.size} rows"
      per_page = 300
      rows.in_groups_of( per_page ) do |grp|
        pairs = grp.compact.map do |row|
          calflora_id, source = row
          next if calflora_id.blank?
          observation_id = calflora_id[/in:(.+)/, 1]
          if observation_id.blank? && !source.blank?
            observation_id = source[/inaturalist\.org\/observations\/([^\/\?]+)/, 1]
          end
          [calflora_id, observation_id]
        end
        obs_ids = pairs.compact.map(&:last).compact
        observations = Observation.page_of_results( id: obs_ids, per_page: per_page ).index_by(&:id)
        observation_links = ObservationLink.where( observation_id: obs_ids ).group_by(&:observation_id)
        pairs.each do |calflora_id, observation_id|
          next unless calflora_id
          logger.debug calflora_id
          observation = observations[observation_id.to_i]
          if observation.blank?
            logger.debug "\tobservation #{observation_id} doesn't exist, skipping..."
            next
          end
          href = "http://www.calflora.org/cgi-bin/noccdetail.cgi?seq_num=#{calflora_id}"
          existing = ( observation_links[observation_id.to_i] || [] ).detect{|ol| ol.href == href}
          if existing
            existing.touch unless @opts[:debug]
            @old_count += 1
            logger.debug "\tobservation link already exists, skipping"
          else
            ol = ObservationLink.new(
              observation: observation,
              href: href,
              href_name: @data_partner.name,
              rel: "alternate"
            )
            unless ol.valid?
              logger.error "#{ol} not valid: #{ol.errors.full_messages.to_sentence}"
            end
            ol.save unless @opts[:debug]
            @new_count += 1
            @obs_ids_to_index << observation.id
            logger.debug "\tCreated #{ol}"
          end
        end
      end
    end
  end
end
