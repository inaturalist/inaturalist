# frozen_string_literal: true

module DataPartnerLinkers
  class Eddmaps < DataPartnerLinkers::DataPartnerLinker
    CSV_GZ_URL = "https://bugwoodcloud.org/downloads/inaturalist/eddmaps-to-inaturalist.csv.gz"

    def download
      filename = File.basename( CSV_GZ_URL )
      tmp_path = File.join( Dir.tmpdir, File.basename( __FILE__, ".*" ) )
      archive_path = File.join( tmp_path, filename )
      FileUtils.mkdir_p tmp_path, mode: 0755
      unless File.exist?( archive_path )
        system_call "curl -L -o #{archive_path} #{CSV_GZ_URL}"
      end
      system_call "gunzip --force #{archive_path}"
      csv_filename = File.basename( CSV_GZ_URL, ".gz" )
      csv_path = File.join( tmp_path, csv_filename )
      unless File.exist?( csv_path )
        raise "Unzipped file does not exist at #{csv_path}"
      end

      csv_path
    end

    def run
      start_time = Time.now
      new_count = 0
      old_count = 0
      num_indexed = 0
      observation_ids = []

      csv_path = download
      puts "parsing #{csv_path}"
      CSV.foreach( csv_path, headers: true ) do | row |
        observation_id = row[0]
        observation = Observation.find_by_id( observation_id )
        if observation.blank?
          logger.debug "\tobservation #{observation_id} doesn't exist, skipping..."
          next
        end
        href = row[2]
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

      # Reindex affected obs
      observation_ids.in_groups_of( 500 ) do | group |
        Observation.elastic_index!( ids: group.compact, wait_for_index_refresh: true ) unless @opts[:debug]
        num_indexed += group.size
        logger.info "#{num_indexed} re-indexed (#{( num_indexed / observation_ids.size.to_f * 100 ).round( 2 )})"
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
