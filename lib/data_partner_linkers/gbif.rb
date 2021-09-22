module DataPartnerLinkers
  class GBIF < DataPartnerLinkers::DataPartnerLinker
    def initialize( data_partner, options = {} )
      super( data_partner, options )
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
      zip_url = "http://api.gbif.org/v0.9/occurrence/download/request/#{@key}.zip"
      status_url = "http://api.gbif.org/v0.9/occurrence/download/#{@key}"
      @num_checks ||= 0
      logger.debug "[#{Time.now}] Checking #{status_url}" if @num_checks == 0
      resp = RestClient.get(status_url)
      @status = JSON.parse( resp )
      @num_checks += 1
      @status["status"] != "SUCCEEDED"
      case @status["status"]
      when "PREPARING", "RUNNING" then return true
      when "SUCCEEDED" then return false
      else
        raise DataPartnerLinkerError.new( "Failed to retrieve GBIF archive: #{@status}" )
      end
    end

    def download
      url = "http://api.gbif.org/v0.9/occurrence/download/request/#{@key}.zip"
      filename = File.basename(url)
      @tmp_path = File.join(Dir::tmpdir, "#{File.basename(__FILE__, ".*")}-#{@key}")
      archive_path = "#{@tmp_path}/#{filename}"
      work_path = @tmp_path
      FileUtils.mkdir_p @tmp_path, mode: 0755
      unless File.exists?("#{@tmp_path}/#{filename}")
        system_call "curl -L -o #{@tmp_path}/#{filename} #{url}"
      end
      system_call "unzip -d #{@tmp_path} #{@tmp_path}/#{filename}"
    end

    def run
      start_time = Time.now
      new_count = 0
      old_count = 0
      delete_count = 0
      count = 0
      request
      logger.info "[#{Time.now}] Waiting for archive to generate..."
      while generating
        print "."
        sleep 3
      end
      logger.info
      logger.info "[#{Time.now}] Downloading archive..."
      download
      obs_ids_to_index = []
      # "\x00" is an unprintable character that I hope we can assume will never appear in the data. If it does, CSV will choke
      CSV.foreach(File.join(@tmp_path, "occurrence.txt"), col_sep: "\t", headers: true, quote_char: "\x00") do |row|
        # puts "row['gbifID']: #{row['gbifID']}\t\trow['catalogNumber']: #{row['catalogNumber']}"
        observation_id = row['catalogNumber']
        gbif_id = row['gbifID']
        logger.info [
          gbif_id.to_s.ljust(20), 
          "#{count} of #{@status['totalRecords']} (#{(count / @status['totalRecords'].to_f * 100).round(2)}%)".ljust(30),
          "#{((Time.now - start_time) / 60.0).round(2)} mins"
          ].join(' ')
        observation = Observation.find_by_id(observation_id)
        if observation.blank?
          logger.info "\tobservation #{observation_id} doesn't exist, skipping..." if @opts[:debug]
          next
        end
        href = "http://www.gbif.org/occurrence/#{gbif_id}"
        existing = ObservationLink.where(observation_id: observation_id, href: href).first
        if existing
          existing.touch unless @opts[:debug]
          old_count += 1
          logger.info "\tobservation link already exists for observation #{observation_id}, skipping" if @opts[:debug]
        else
          ol = ObservationLink.new( observation: observation, href: href, href_name: "GBIF", rel: "alternate" )
          ol.save unless @opts[:debug]
          new_count += 1
          obs_ids_to_index << observation.id
          # puts "\tCreated #{ol}"
        end
        count += 1
      end

      links_to_delete_scope = ObservationLink.where("href_name = 'GBIF' AND updated_at < ?", start_time)
      delete_count = links_to_delete_scope.count
      logger.info
      logger.info "[#{Time.now}] Deleting #{delete_count} observation links..."
      obs_ids_to_index += links_to_delete_scope.pluck(:observation_id)
      obs_ids_to_index = obs_ids_to_index.compact.uniq
      links_to_delete_scope.delete_all unless @opts[:debug]

      logger.info
      logger.info "[#{Time.now}] Re-indexing #{obs_ids_to_index.size} observations..."
      obs_ids_to_index.in_groups_of( 500 ) do |group|
        Observation.elastic_index!( ids: group.compact, wait_for_index_refresh: true ) unless @opts[:debug]
        num_indexed += group_size
        puts "[#{Time.now}] #{num_indexed} re-indexed (#{( num_indexed / obs_ids_to_index.size.to_f * 100 ).round( 2 )})"
      end
      logger.info "[#{Time.now}] Finished linking for #{@data_partner}"
    end
  end
end
