# frozen_string_literal: true

module DataPartnerLinkers
  class GBIF < DataPartnerLinkers::DataPartnerLinker
    MAX_OBSERVATION_INDEX_QUEUE_SIZE = 10_000

    # GBIF dataset key for the iNaturalist Research-grade Observations dataset
    DATASET_KEY = "50c9509d-22c7-4a22-a47d-8c48425ef4a7"

    DOWNLOAD_REQUEST_ENDPOINT = "api.gbif.org/v1/occurrence/download/request"

    def initialize( data_partner, options = {} )
      super
      @username = options[:username] || CONFIG.gbif.username
      @password = options[:password] || CONFIG.gbif.password
      @notification_address = options[:notification_address] || CONFIG.gbif.notification_address
    end

    def request
      json = {
        creator: @username,
        notification_address: [@notification_address],
        predicate: {
          type: "and",
          predicates: [
            {
              type: "equals",
              key: "DATASET_KEY",
              value: DATASET_KEY
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
      logger.debug "Requesting https://#{DOWNLOAD_REQUEST_ENDPOINT}"
      logger.debug "With JSON: #{json}"
      @key = RestClient.post download_request_url, json, content_type: :json, accept: :json
      logger.debug "Received key: #{@key}"
    end

    # Requests an occurrence download via GBIF's SQL Downloads API instead of
    # the predicate API. The SQL selects only the columns process_result reads
    # (gbifID, catalogNumber), so GBIF generates a much smaller archive.
    # See https://techdocs.gbif.org/en/data-use/api-sql-downloads
    def request_filtered
      json = {
        sendNotification: true,
        notificationAddresses: [@notification_address],
        format: "SQL_TSV_ZIP",
        sql: "SELECT gbifID, catalogNumber FROM occurrence WHERE datasetKey = '#{DATASET_KEY}'"
      }.to_json
      logger.debug "Requesting https://#{DOWNLOAD_REQUEST_ENDPOINT}"
      logger.debug "With JSON: #{json}"
      @key = RestClient.post download_request_url, json, content_type: :json, accept: :json
      logger.debug "Received key: #{@key}"
    end

    # Credentials must be escaped or characters like "@" would break the URI.
    # RestClient unescapes URI userinfo before using it for basic auth. Never
    # log this URL: it contains the credentials.
    def download_request_url
      "https://#{CGI.escape( @username )}:#{CGI.escape( @password )}@#{DOWNLOAD_REQUEST_ENDPOINT}"
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

      logger.info( "[#{@process_start_time}] #process_result begun" )

      rows_queue = []
      # "\x00" is an unprintable character that I hope we can assume will
      #   never appear in the data. If it does, CSV will choke.
      # Headers are downcased so both the predicate DwC-A ("gbifID",
      # "catalogNumber") and the SQL download ("gbifid", "catalognumber")
      # resolve to the same keys in process_rows.
      csv_options = {
        col_sep: "\t",
        headers: true,
        header_converters: ->( header ) { header.to_s.downcase },
        quote_char: "\x00"
      }
      CSV.foreach( occurrence_file_path, **csv_options ) do | row |
        rows_queue << row
        if rows_queue.size >= MAX_OBSERVATION_INDEX_QUEUE_SIZE
          # We could also hand off each batch of rows to a DelayedJob,
          # however we would need a way to only delete all the non-updated
          # ObservationLinks only when all rows have succesfully processed.
          process_rows( rows_queue )
          rows_queue = []
        end
      end
      process_rows( rows_queue )
      logger.info(
        "[#{Time.now}]<#{@process_start_time}> process_result done on " \
          "#{@processed_count} records in #{Time.now - @process_start_time}"
      )
    end

    # The predicate API returns a Darwin Core Archive with an "occurrence.txt".
    # The SQL Downloads API returns a single tab-separated data file named for
    # the download key (e.g. "0000379-xxx.csv"), so locate it by extension.
    def occurrence_file_path
      return File.join( @tmp_path, "occurrence.txt" ) unless @opts[:sql_download]

      Dir.glob( File.join( @tmp_path, "*.{csv,tsv}" ) ).first
    end

    def gbif_href( gbif_id )
      "http://www.gbif.org/occurrence/#{gbif_id}"
    end

    def process_rows( rows )
      return if rows.empty?

      observation_ids = rows.map {| row | row["catalognumber"].to_i }
      # The exact (observation_id, href) pairs we want to keep/create this batch.
      wanted_pairs = rows.to_set {| row | [row["catalognumber"].to_i, gbif_href( row["gbifid"] )] }

      # Fetch this batch's existing GBIF links with a single-column IN, then
      # match the exact pairs in memory. A row-value tuple IN of the pairs would
      # match exactly too, but Postgres expands (a,b) IN (...) into a deep
      # boolean tree that overflows max_stack_depth for large batches
      # (PG::StatementTooComplex). A single-column integer IN does not.
      existing_link_pairs = Set.new
      matching_link_ids = []
      ObservationLink.where( href_name: "GBIF", observation_id: observation_ids ).
        pluck( :id, :observation_id, :href ).each do | link_id, link_observation_id, link_href |
        pair = [link_observation_id, link_href]
        next unless wanted_pairs.include?( pair )

        existing_link_pairs << pair
        matching_link_ids << link_id
      end

      existing_observation_ids = Observation.where( id: observation_ids ).pluck( :id ).to_set
      ObservationLink.where( id: matching_link_ids ).touch_all unless @opts[:debug]

      ObservationLink.transaction do
        rows.each do | row |
          gbif_id = row["gbifid"]
          inaturalist_observation_id = row["catalognumber"].to_i
          if ( @processed_count % MAX_OBSERVATION_INDEX_QUEUE_SIZE ).zero?
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

          href = gbif_href( gbif_id )
          if existing_link_pairs.include?( [inaturalist_observation_id, href] )
            @old_count += 1
            @processed_count += 1
            next
          end

          unless existing_observation_ids.include?( inaturalist_observation_id )
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
      # send a request to generate an offline download. The SQL Downloads API
      # (request_filtered) returns only the columns we use, for a smaller
      # archive; the predicate API (request) returns the full occurrence record.
      if @opts[:sql_download]
        request_filtered
      else
        request
      end
      # wait for the download file to generate
      logger.info( "[#{Time.now}] Waiting for archive to generate..." )
      # It takes about 40 minutes for GBIF to succesfully generate the export.
      # We should probably handle this delay with a delayed job with retry behavior,
      # rather than a while loop in process.
      while generating
        print "."
        sleep 60
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

      logger.info( "[#{Time.now}] Finished linking for #{@data_partner || 'GBIF'}" )
      logger.info( "[#{Time.now}] Indexing may continue in delayed jobs\n\n" )
    end
  end
end
