# frozen_string_literal: true

module DataPartnerLinkers
  class GBIF < DataPartnerLinkers::DataPartnerLinker
    MAX_OBSERVATION_INDEX_QUEUE_SIZE = 1000

    def initialize( data_partner, options = {} )
      super
      @username = options[:username] || CONFIG.gbif.username
      @password = options[:password] || CONFIG.gbif.password
      @notification_address = options[:notification_address] || CONFIG.gbif.notification_address
    end

    def request
      url = "https://#{@username}:#{@password}@api.gbif.org/v1/occurrence/download/request"
      json = {
        creator: @username,
        notification_address: [@notification_address],
        predicate: {
          type: "and",
          predicates: [
            {
              type: "equals",
              key: "DATASET_KEY",
              # I know, hardcoding, not great, but does this really need to be
              # configurable?
              value: "50c9509d-22c7-4a22-a47d-8c48425ef4a7"
            }
            # {
            #   type: "equals",
            #   key: "TAXON_KEY",
            #   # Uncomment one of the following for testing. Note that this is
            #   # the GBIF species ID
            #   # value: 5420950 # Clarkia breweri
            #   # value: 3114255 # Hemizonella
            # }
          ]
        }
      }.to_json
      logger.debug "Requesting #{url}"
      logger.debug "With JSON: #{json}"
      @key = RestClient.post url, json, content_type: :json, accept: :json
      logger.debug "Received key: #{@key}"
    end

    def generating
      status_url = "http://api.gbif.org/v0.9/occurrence/download/#{@key}"
      @num_checks ||= 0
      logger.debug "[#{Time.now}] Checking #{status_url}" if @num_checks.zero?
      resp = RestClient.get( status_url )
      @status = JSON.parse( resp )
      @num_checks += 1
      case @status["status"]
      when "PREPARING", "RUNNING" then true
      when "SUCCEEDED" then false
      else
        raise DataPartnerLinkerError, "Failed to retrieve GBIF archive: #{@status}"
      end
    end

    def download
      url = "http://api.gbif.org/v0.9/occurrence/download/request/#{@key}.zip"
      filename = File.basename( url )
      @tmp_path = File.join( Dir.tmpdir, "#{File.basename( __FILE__, '.*' )}-#{@key}" )
      FileUtils.mkdir_p @tmp_path, mode: 0o755
      unless File.exist?( "#{@tmp_path}/#{filename}" )
        system_call "curl -L -o #{@tmp_path}/#{filename} #{url}"
      end
      system_call "unzip -d #{@tmp_path} #{@tmp_path}/#{filename}"
    end

    def process_result
      @total_records = @status["totalRecords"]
      @observation_index_queue = []
      @process_start_time = Time.now
      @processed_count = 0
      @old_count = 0
      @new_count = 0
      @missing_count = 0
      rows_queue = []
      occurrence_path = File.join( @tmp_path, "occurrence.txt" )
      # "\x00" is an unprintable character that I hope we can assume will
      #   never appear in the data. If it does, CSV will choke
      CSV.foreach( occurrence_path, col_sep: "\t", headers: true, quote_char: "\x00" ) do | row |
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
          gbif_id = row["gbifID"]
          inaturalist_observation_id = row["catalogNumber"]
          if ( @processed_count % 1000 ).zero?
            percent_finished = ( @processed_count / @total_records.to_f * 100 ).round( 2 )
            run_time = Time.now - @process_start_time
            minutes_elapsed = ( run_time / 60.0 ).round( 2 )
            avg_row_time = run_time / @processed_count
            minutes_left = ( ( ( @total_records - @processed_count ) * avg_row_time ) / 60 ).round( 2 )

            logger.info( [
              gbif_id.to_s.ljust( 20 ),
              "#{@processed_count} of #{@total_records} (#{percent_finished}%)".ljust( 30 ),
              "#{minutes_elapsed} min in".ljust( 15 ),
              "#{minutes_left} min left".ljust( 15 ),
              "Old: #{@old_count}",
              "New: #{@new_count}",
              "Missing: #{@missing_count}"
            ].join( " " ) )
          end

          href = "http://www.gbif.org/occurrence/#{gbif_id}"
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
            href_name: "GBIF",
            rel: "alternate"
          )
          observation_link.save unless @opts[:debug]
          @new_count += 1
          add_observation_to_index_queue( inaturalist_observation_id.to_i )
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
      return if @observation_index_queue.blank?

      @total_indexed_observations ||= 0
      @total_indexed_observations += @observation_index_queue.size
      logger.info( "\tIndexing #{@observation_index_queue.size} observations" )
      logger.info( "\tTotal indexed: #{@total_indexed_observations}" )
      unless @opts[:debug]
        # adding a small delay to the indexing job as some processing is done
        # in transactions and may not immediately available to other processes
        Observation.elastic_index!(
          ids: @observation_index_queue,
          delay: true,
          batch_size: MAX_OBSERVATION_INDEX_QUEUE_SIZE,
          run_at: 1.minute.from_now
        )
      end
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
        sleep 3
      end

      # download the resulting zip file
      logger.info( "[#{Time.now}] Downloading archive..." )
      download
      # process the download to add and update links
      logger.info( "[#{Time.now}] Creating/Updating ObservationLinks..." )
      process_result
      # index any observations left in the queue
      index_observation_queue

      links_to_delete_scope = ObservationLink.where( "href_name = 'GBIF' AND updated_at < ?", start_time )
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
