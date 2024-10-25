# frozen_string_literal: true

module DataPartnerLinkers
  class ALA < DataPartnerLinkers::DataPartnerLinker
    MAX_OBSERVATION_INDEX_QUEUE_SIZE = 1000

    def initialize( data_partner, options = {} )
      super
    end

    def request
      parameters = {
        email: CONFIG.admin_user_email,
        fields: "id", # return only ID (ALA's UUID) from main fields
        extra: "catalogNumber", # also return iNaturalist integer observation ID
        sep: "%2C", # comma: ,
        esc: "%22", # quote: "
        dwcHeaders: "false",
        includeMisc: "false",
        qa: "none",
        reasonTypeId: "11", # see https://logger.ala.org.au/service/logger/reasons
        sourceTypeId: "0", # see https://logger.ala.org.au/service/logger/sources
        fileType: "csv",
        mintDoi: "false",
        q: "dataResourceUid:dr1411" # filter by iNaturalist observations
      }
      base_url = "https://api.ala.org.au/occurrences/occurrences/offline/download?"
      url = base_url + CGI.unescape( parameters.to_query )
      logger.debug "Requesting base URL: #{base_url}"
      logger.debug "With parameters: #{parameters}"
      response = RestClient.get( url )
      download_request_response = JSON.parse( response )
      @status_url = download_request_response["statusUrl"]
      logger.debug "Download queued: #{@status_url}"
    end

    def generating
      @num_checks ||= 0
      logger.debug "[#{Time.now}] Checking #{@status_url}" if @num_checks.zero?
      response = RestClient.get( @status_url )
      @status_response = JSON.parse( response )
      @num_checks += 1
      status_string = @status_response["status"]
      case status_string
      when "inQueue", "running"
        true
      when "finished"
        false
      else
        raise DataPartnerLinkerError.new( "Failed to retrieve ALA archive: #{status_string}" )
      end
    end

    def download
      download_url = @status_response["downloadUrl"]
      @download_filename = File.basename( download_url )
      download_key = File.basename( @status_url )
      @tmp_path = File.join( Dir.tmpdir, "ala-#{download_key}" )
      FileUtils.mkdir_p( @tmp_path, mode: 0o755 )
      return if File.exist?( "#{@tmp_path}/#{@download_filename}" )

      system_call "curl -L -o #{@tmp_path}/#{@download_filename} #{download_url}"
      system_call "unzip -d #{@tmp_path} #{@tmp_path}/#{@download_filename}"
    end

    def process_result
      @total_records = @status_response["totalRecords"]
      @observation_index_queue = []
      @process_start_time = Time.now
      @processed_count = 0
      @old_count = 0
      @new_count = 0
      @missing_count = 0
      rows_queue = []
      data_csv_path = File.join( @tmp_path, "data.csv" )
      CSV.foreach( data_csv_path, col_sep: ",", headers: true, quote_char: "\"" ) do | row |
        rows_queue << row
        if rows_queue.size >= 1000
          process_rows( rows_queue )
          rows_queue = []
        end
      end
      process_rows( rows_queue )
    end

    def process_rows( rows )
      return if rows.empty?

      ObservationLink.transaction do
        rows.each do | row |
          ala_uuid = row["Record ID"]
          inaturalist_observation_id = row["Catalogue Number"]
          if ( @processed_count % 1000 ).zero?
            percent_finished = ( @processed_count / @total_records.to_f * 100 ).round( 2 )
            run_time = Time.now - @process_start_time
            minutes_elapsed = ( run_time / 60.0 ).round( 2 )
            avg_row_time = run_time / @processed_count
            minutes_left = ( ( ( @total_records - @processed_count ) * avg_row_time ) / 60 ).round( 2 )

            logger.info( [
              ala_uuid,
              "#{@processed_count} of #{@total_records} (#{percent_finished}%)".ljust( 30 ),
              "#{minutes_elapsed} min in".ljust( 15 ),
              "#{minutes_left} min left".ljust( 15 ),
              "Old: #{@old_count}",
              "New: #{@new_count}",
              "Missing: #{@missing_count}"
            ].join( " " ) )
          end

          href = "http://biocache.ala.org.au/occurrences/#{ala_uuid}"
          count_touched = if @opts[:debug]
            ObservationLink.where( observation_id: inaturalist_observation_id, href: href ).count
          else
            ObservationLink.where( observation_id: inaturalist_observation_id, href: href ).touch_all
          end
          if count_touched.positive?
            @old_count += 1
            @processed_count += 1
            next
          end

          unless Observation.where( id: inaturalist_observation_id ).exists?
            if @opts[:debug]
              logger.info( "\tobservation #{inaturalist_observation_id} doesn't exist, skipping..." )
            end
            @missing_count += 1
            @processed_count += 1
            next
          end

          observation_link = ObservationLink.new(
            observation_id: inaturalist_observation_id,
            href: href,
            href_name: "Atlas of Living Australia",
            rel: "alternate"
          )
          observation_link.save unless @opts[:debug]
          @new_count += 1
          add_observation_to_index_queue( inaturalist_observation_id )
          @processed_count += 1
        end
      end
    end

    def add_observation_to_index_queue( observation_id )
      @observation_index_queue ||= []
      @observation_index_queue << observation_id
      return unless @observation_index_queue.size >= MAX_OBSERVATION_INDEX_QUEUE_SIZE

      index_observation_queue
    end

    def index_observation_queue
      return if @observation_index_queue.empty?

      @total_indexed_observations ||= 0
      @total_indexed_observations += @observation_index_queue.size
      logger.info( "\tIndexing #{@observation_index_queue.size} observations" )
      logger.info( "\tTotal indexed: #{@total_indexed_observations}" )
      # adding a small delay to the indexing job as some processing is done
      # in transactions and may not immediately available to other processes
      Observation.elastic_index!(
        ids: @observation_index_queue,
        delay: true,
        batch_size: MAX_OBSERVATION_INDEX_QUEUE_SIZE,
        run_at: 1.minute.from_now
      )
      @observation_index_queue = []
    end

    def run
      start_time = Time.now
      # send a request to generate an offline download
      request
      # wait for the download file to generate
      logger.info( "[#{Time.now}] Waiting for archive to generate..." )
      while generating
        print "."
        sleep 5
      end

      # download the resulting zip file
      logger.info( "[#{Time.now}] Downloading archive..." )
      download
      # process the download to add and update links
      logger.info( "[#{Time.now}] Creating/Updating ObservationLinks..." )
      process_result
      # index any observations left in the queue
      index_observation_queue

      links_to_delete_scope = ObservationLink.where(
        "href_name = 'Atlas of Living Australia' AND updated_at < ?",
        start_time
      )
      delete_count = links_to_delete_scope.count
      logger.info( "[#{Time.now}] Deleting #{delete_count} observation links..." )
      @observation_index_queue = links_to_delete_scope.pluck( :observation_id ).uniq
      links_to_delete_scope.delete_all unless @opts[:debug]
      index_observation_queue

      logger.info( "[#{Time.now}] Finished linking for #{@data_partner}" )
      logger.info( "[#{Time.now}] Indexing may continue in delayed jobs\n\n" )
    end
  end
end
