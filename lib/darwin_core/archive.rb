module DarwinCore
  class Archive

    def self.generate(opts = {})
      new(opts).generate
    end

    def initialize(opts = {})
      @opts = opts.clone.symbolize_keys
      @opts[:path] ||= "dwca.zip"
      @opts[:core] ||= DarwinCore::Cores::OCCURRENCE
      @opts[:extensions] = [@opts[:extensions]].flatten.compact
      @opts[:metadata] ||= if @opts[:core] == DarwinCore::Cores::OCCURRENCE
        File.join(Rails.root, "app", "views", "observations", "dwc.eml.erb")
      else
        File.join(Rails.root, "app", "views", "taxa", "dwc.eml.erb")
      end
      @opts[:descriptor] ||= File.join(Rails.root, "app", "views", "observations", "dwc.descriptor.builder")
      @opts[:quality] ||= @opts[:quality_grade] || "research"
      @opts[:photo_licenses] ||= ["CC0", "CC-BY", "CC-BY-NC", "CC-BY-SA", "CC-BY-ND", "CC-BY-NC-SA", "CC-BY-NC-ND"]
      @opts[:licenses] ||= ["any"]
      @opts[:licenses] = @opts[:licenses].first if @opts[:licenses].size == 1
      @opts[:private_coordinates] ||= false
      @opts[:taxon_private_coordinates] ||= false
      @opts[:photographed_taxa] ||= false
      @logger = @opts[:logger] || Rails.logger
      @logger.level = Logger::DEBUG if @opts[:debug]

      # Make a unique dir to put our files
      @opts[:work_path] = Dir.mktmpdir
      FileUtils.mkdir_p @opts[:work_path], :mode => 0755

      @place = Place.find_by_id(@opts[:place].to_i) || Place.find_by_name(@opts[:place])
      logger.debug "Found place: #{@place}"
      @taxa = [@opts[:taxon]].flatten.compact.map do |taxon|
        if taxon.is_a?( Taxon )
          taxon
        else
          taxon.to_s.split( "," ).map do |t|
            ::Taxon.find_by_id( t.to_i ) || ::Taxon.active.find_by_name( t )
          end
        end
      end.flatten.compact
      logger.debug "Found taxa: "
      unless @taxa.blank?
        @taxa.each do |t|
          logger.debug "\t#{t}"
        end
      end
      @project = if @opts[:project].is_a?(::Project)
        @opts[:project]
      else
        ::Project.find( @opts[:project] ) rescue nil
      end
      logger.debug "Found project: #{@project}"
      logger.debug "Photo licenses: #{@opts[:photo_licenses].inspect}"
    end

    def logger
      @logger || Rails.logger
    end

    def generate
      @generate_started_at = Time.now
      logger.debug "[DEBUG] Generating archive, options: #{@opts}"
      unless @opts[:metadata].to_s.downcase == "skip"
        metadata_path = make_metadata
        logger.debug "Metadata: #{metadata_path}"
      end
      descriptor_path = make_descriptor
      logger.debug "Descriptor: #{descriptor_path}"
      data_paths = make_data
      logger.debug "Data: #{data_paths.inspect}"
      paths = [metadata_path, descriptor_path, data_paths].flatten.compact
      if @opts[:with_taxa]
        logger.info "Making taxa extension..."
        paths += make_api_all_taxon_data
      end
      archive_path = make_archive(*paths)
      logger.debug "Archive: #{archive_path}"
      FileUtils.mv(archive_path, @opts[:path])
      logger.info "Archive generated: #{@opts[:path]}"
      if @benchmarks
        logger.info %w(BENCHMARK TOTAL AVG).map{|h| h.ljust( 30 )}.join( " " )
        @benchmarks.each do |key, times|
          logger.info [key, times.sum.round(5), (times.sum.to_f / times.size).round(5)].map{|h| h.to_s.ljust( 30 )}.join( " " )
        end
      end
      if @opts[:additional_with_taxa_path]
        logger.info "Making taxa extension..."
        paths << make_api_all_taxon_data
        archive_path = make_archive(*paths)
        logger.debug "Moving #{archive_path} to #{@opts[:additional_with_taxa_path]}"
        FileUtils.mv(archive_path, @opts[:additional_with_taxa_path])

        # Make a POST request to an endpoint indicating the archive with taxon data is updated
        if @opts[:post_taxon_archive_to_url] && @opts[:post_taxon_archive_as_url]
          options = {
           body: {
              name: "iNaturalist",
              url: @opts[:post_taxon_archive_as_url]
           }.to_json,
           headers: {
             "Content-Type" => "application/json"
           }
          }
          logger.debug "Posting #{options[:body]} to #{@opts[:post_taxon_archive_to_url]}"
          response = HTTParty.post( @opts[:post_taxon_archive_to_url], options )
        end
      end
      @opts[:path]
    end

    def make_metadata
      metadata_observation_params = observations_params
      if !metadata_observation_params[:created_d2]
        metadata_observation_params[:created_d2] = Time.now
      end
      m = DarwinCore::Metadata.new( @opts.merge(
        observations_params: metadata_observation_params
      ) )
      tmp_path = File.join(@opts[:work_path], "metadata.eml.xml")
      open(tmp_path, 'w') do |f|
        f << m.render(:file => @opts[:metadata])
      end
      tmp_path
    end

    def make_descriptor
      extensions = []
      if @opts[:extensions]
        @opts[:extensions].each do |e|
          case e
          when "EolMedia"
            extensions << {
              :row_type => "http://eol.org/schema/media/Document",
              :files => ["media.csv"],
              :terms => DarwinCore::EolMedia::TERMS
            }
          when "SimpleMultimedia"
            extensions << {
              row_type: "http://rs.gbif.org/terms/1.0/Multimedia",
              files: ["media.csv"],
              terms: DarwinCore::SimpleMultimedia::TERMS
            }
          when "ObservationFields"
            extensions << {
              row_type: "http://www.inaturalist.org/observation_fields",
              files: ["observation_fields.csv"],
              terms: DarwinCore::ObservationFields::TERMS
            }
          when "ProjectObservations"
            extensions << {
              row_type: "http://www.inaturalist.org/project_observations",
              files: ["project_observations.csv"],
              terms: DarwinCore::ProjectObservations::TERMS
            }
          when "User"
            extensions << {
              row_type: "http://www.inaturalist.org/user",
              files: ["users.csv"],
              terms: DarwinCore::User::TERMS
            }
          when "VernacularNames"
            extensions << DarwinCore::VernacularName.descriptor
          end
        end
      end
      d = DarwinCore::Descriptor.new(core: @opts[:core], extensions: extensions, ala: @opts[:ala])
      tmp_path = File.join(@opts[:work_path], "meta.xml")
      open(tmp_path, 'w') do |f|
        f << d.render(:file => @opts[:descriptor])
      end
      tmp_path
    end

    def make_data
      paths = [send("make_#{@opts[:core]}_data")]
      if @opts[:extensions]
        @opts[:extensions].each do |ext|
          ext = ext.underscore.downcase
          logger.info "Making #{ext} extension..."
          paths += send("make_#{ext}_data")
        end
      end
      paths
    end

    def observations_params
      params = {}
      params[:license] = [@opts[:licenses]].flatten.compact.join( "," ) unless @opts[:licenses].include?( "ignore" )
      params[:place_id] = @place.id if @place
      params[:taxon_ids] = @taxa.map(&:id) if @taxa
      params[:projects] = [@project.id] if @project
      params[:quality_grade] = @opts[:quality] === "verifiable" ? "research,needs_id" : @opts[:quality]
      params[:site_id] = @opts[:site_id]
      params[:created_d1] = @opts[:created_d1]
      params[:created_d2] = @opts[:created_d2]
      if @opts[:photos].to_s == "true"
        params[:with_photos] = true
      elsif @opts[:photos].to_s == "false"
        params[:with_photos] = false
      end
      params[:ofv_datatype] = @opts[:ofv_datatype]
      if !( @opts[:swlat].blank? || @opts[:swlng].blank? || @opts[:nelat].blank? || @opts[:nelng].blank? )
        params[:swlat] = @opts[:swlat]
        params[:swlng] = @opts[:swlng]
        params[:nelat] = @opts[:nelat]
        params[:nelng] = @opts[:nelng]
      end
      params
    end

    def benchmark( key )
      if @opts[:benchmark]
        @benchmarks ||= {}
        @benchmarks[key] ||= []
        start = Time.now
        yield
        @benchmarks[key] << Time.now - start
      else
        yield
      end
    end

    def make_occurrence_data
      terms = DarwinCore::Occurrence::TERMS
      if @opts[:ala]
        terms += DarwinCore::Occurrence::ALA_EXTRA_TERMS
      end
      headers = DarwinCore::Occurrence.term_names( terms )
      fname = "observations.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      fake_view = FakeView.new
      
      preloads = [
        { taxon: :ancestor_taxa },
        { user: [:stored_preferences, :provider_authorizations] }, 
        :quality_metrics, 
        { identifications: { user: [:provider_authorizations] } },
        { observations_places: :place },
        { annotations: { controlled_value: [:labels], votes_for: {} } }
      ]

      if @opts[:community_taxon]
        preloads  << { community_taxon: :ancestor_taxa }
      end
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, logger: logger ) do
        CSV.open(tmp_path, 'w') do |csv|
          csv << headers
          observations_in_batches( observations_params, preloads, label: "make_occurrence_data" ) do |o|
            benchmark(:obs) do
              private_coordinates = if @opts[:private_coordinates]
                true
              elsif @opts[:taxon_private_coordinates]
                [nil, Observation::OPEN].include?( o.geoprivacy )
              end
              o = DarwinCore::Occurrence.adapt(o, view: fake_view,
                private_coordinates: private_coordinates,
                community_taxon: @opts[:community_taxon]
              )
              row = terms.map do |field, uri, default, method|
                key = method || field
                benchmark( "obs_#{key}" ) { o.send( key ) }
              end
              benchmark(:obs_csv_row) { csv << row }
            end
          end
        end
      end
      
      [tmp_path]
    end

    def make_taxon_data
      headers = DarwinCore::Taxon::TERM_NAMES
      fname = "taxa.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      
      scope = ::Taxon.select( "DISTINCT ON (taxa.id) taxa.*" )
      
      if @opts[:photographed_taxa]
        licenses = @opts[:photo_licenses].map do |license_code|
          Photo.license_number_for_code(license_code)
        end
        scope = scope.
          joins(:observations => {:observation_photos => :photo}).
          where(
            "rank_level <= ? AND observation_photos.id IS NOT NULL AND photos.license IN (?)",
            ::Taxon::SPECIES_LEVEL,
            licenses
          )
        if @opts[:quality] == "research"
          scope = scope.where("observations.quality_grade = ?", Observation::RESEARCH_GRADE)
        elsif @opts[:quality] == "casual"
          scope = scope.where("observations.quality_grade = ?", Observation::CASUAL_GRADE)
        elsif @opts[:quality] == "verifiable"
          scope = scope.where("observations.quality_grade IN (?, ?)", Observation::RESEARCH_GRADE, Observation::NEEDS_ID)
        end
      else
        scope = scope.where( "is_active" )
      end

      CSV.open(tmp_path, 'w') do |csv|
        csv << headers
        if @taxa.blank?
          scope.find_each do |t|
            DarwinCore::Taxon.adapt(t)
            csv << DarwinCore::Taxon::TERMS.map{|field, uri, default, method| t.send(method || field)}
          end
        else
          @taxa.each do |taxon|
            taxon_scope = scope.where( taxon.descendant_conditions[0] )
            taxon_scope.find_each do |t|
              DarwinCore::Taxon.adapt(t)
              csv << DarwinCore::Taxon::TERMS.map{|field, uri, default, method| t.send(method || field)}
            end
          end
        end
      end
      
      [tmp_path]
    end

    def make_eol_media_data
      headers = DarwinCore::EolMedia::TERM_NAMES
      fname = "media.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      licenses = @opts[:photo_licenses].map do |license_code|
        Photo.license_number_for_code(license_code)
      end
      
      scope = Photo.
        joins(:user, {observation_photos: {observation: :taxon}}).
        where("photos.license IN (?) AND taxa.rank_level <= ? AND taxa.id IS NOT NULL", licenses, ::Taxon::SPECIES_LEVEL)
      
      if @opts[:quality] == "research"
        scope = scope.where("observations.quality_grade = ?", Observation::RESEARCH_GRADE)
      elsif @opts[:quality] == "casual"
        scope = scope.where("observations.quality_grade = ?", Observation::CASUAL_GRADE)
      elsif @opts[:quality] == "verifiable"
        scope = scope.where("observations.quality_grade IN (?, ?)", Observation::RESEARCH_GRADE, Observation::NEEDS_ID)
      end

      if @place
        scope = scope.joins("JOIN place_geometries ON place_geometries.place_id = #{@place.id}")
        scope = scope.where("ST_Intersects(place_geometries.geom, observations.private_geom)")
      end

      CSV.open(tmp_path, 'w') do |csv|
        csv << headers
        if @taxa.blank?
          scope.find_each do |record|
            DarwinCore::EolMedia.adapt(record)
            csv << DarwinCore::EolMedia::TERMS.map{|field, uri, default, method| record.send(method || field)}
          end
        else
          @taxa.each do |taxon|
            taxon_scope = scope.where( taxon.descendant_conditions )
            taxon_scope.find_each do |record|
              DarwinCore::EolMedia.adapt(record)
              csv << DarwinCore::EolMedia::TERMS.map{|field, uri, default, method| record.send(method || field)}
            end
          end
        end
      end
      
      [tmp_path]
    end

    def make_simple_multimedia_data
      headers = DarwinCore::SimpleMultimedia::TERM_NAMES
      fname = "media.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      
      params = observations_params
      media_licenses = @opts[:photo_licenses].map(&:downcase)
      preloads = [
        { observation_photos: { photo: :user } },
        { observation_sounds: { sound: :user } }
      ]

      start_time = @generate_started_at || Time.now
      
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, logger: logger ) do
        CSV.open(tmp_path, 'w') do |csv|
          csv << headers
          observations_in_batches(params, preloads, label: 'make_simple_multimedia_data') do |observation|
            next if observation.observation_photos.blank? && observation.observation_sounds.blank?
            begin
              observation.observation_photos.sort_by{|op| op.position || op.id }.each do |op|
                # If ES is out of sync with the DB, the photo might no longer exist
                next if op.nil?
                next if op.created_at.nil?
                next if op.photo.nil?
                next unless op.created_at <= start_time
                if !media_licenses.include?( "ignore" )
                  next if op.photo.all_rights_reserved?
                  next unless media_licenses.include?( op.photo.license_code.to_s.downcase )
                end
                DarwinCore::SimpleMultimedia.adapt(op.photo, observation: observation, core: @opts[:core])
                csv << DarwinCore::SimpleMultimedia::TERMS.map{|field, uri, default, method| op.photo.send(method || field)}
              end
              observation.observation_sounds.sort_by(&:id).each do |os|
                next if os.nil?
                next if os.created_at.nil?
                next if os.sound.nil?
                next unless os.sound.is_a?( LocalSound ) # Soundcloud sounds don't come with stable file URLs we can share
                next unless os.created_at <= start_time
                if !media_licenses.include?( "ignore" )
                  next if os.sound.all_rights_reserved?
                  next unless media_licenses.include?( os.sound.license_code.to_s.downcase )
                end
                DarwinCore::SimpleMultimedia.adapt( os.sound, observation: observation, core: @opts[:core] )
                csv << DarwinCore::SimpleMultimedia::TERMS.map{|field, uri, default, method| os.sound.send(method || field)}
              end
            rescue => e
              logger.error "make_simple_multimedia_data failed on observation #{observation.id}"
              raise e
            end
          end
        end
      end
      
      [tmp_path]
    end

    def make_observation_fields_data
      headers = DarwinCore::ObservationFields::TERM_NAMES
      fname = "observation_fields.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      
      params = observations_params
      preloads = [ { observation_field_values: :observation_field } ]
      start_time = @generate_started_at || Time.now
      
      # If ES goes down, wait a minute and try again. Repeat a few times then just raise the exception
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, logger: logger ) do
        CSV.open(tmp_path, 'w') do |csv|
          csv << headers
          observations_in_batches(params, preloads, label: 'make_observation_fields_data') do |observation|
            observation.observation_field_values.each do |ofv|
              next unless ofv.created_at <= start_time
              DarwinCore::ObservationFields.adapt(ofv, observation: observation, core: @opts[:core])
              csv << DarwinCore::ObservationFields::TERMS.map{|field, uri, default, method| ofv.send(method || field)}
            end
          end
        end
      end
      
      [tmp_path]
    end

    def make_project_observations_data
      headers = DarwinCore::ProjectObservations::TERM_NAMES
      fname = "project_observations.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      
      params = observations_params
      preloads = [ { project_observations: :project } ]
      start_time = @generate_started_at || Time.now
      
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, logger: logger ) do
        CSV.open(tmp_path, 'w') do |csv|
          csv << headers
          observations_in_batches(params, preloads, label: 'make_project_observations_data') do |observation|
            observation.project_observations.each do |po|
              next unless po.created_at <= start_time
              DarwinCore::ProjectObservations.adapt(po, core: @opts[:core])
              csv << DarwinCore::ProjectObservations::TERMS.map{|field, uri, default, method| po.send(method || field)}
            end
          end
        end
      end
      
      [tmp_path]
    end

    def make_user_data
      headers = DarwinCore::User::TERM_NAMES
      fname = "users.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      
      params = observations_params
      preloads = [ :user ]
      
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, logger: logger ) do
        CSV.open(tmp_path, 'w') do |csv|
          csv << headers
          observations_in_batches( params, preloads, label: "make_user_data") do |observation|
            DarwinCore::User.adapt( observation.user, core: @opts[:core], observation: observation )
            csv << DarwinCore::User::TERMS.map{|field, uri, default, method| observation.user.send(method || field)}
          end
        end
      end
      
      [tmp_path]
    end

    def make_vernacular_names_data
      DarwinCore::VernacularName.data( @opts )
    end

    def make_api_all_taxon_data
      headers = [ "taxonID", "scientificName", "parentNameUsageID", "taxonRank" , "vernacularName", "wikipedia_url" ]
      fname = "taxa.csv"
      tmp_path = File.join(@opts[:work_path], fname)

      params = { is_active: true }
      last_id = 0
      start_time = Time.now
      rows_written = 0
      total_results = nil
      localization_place_id = Place.find_by_name("United States").try(:id)
      CSV.open(tmp_path, "w") do |csv|
        csv << headers
        beginning_or_more_results = true
        while beginning_or_more_results
          begin
            response = INatAPIService.taxa( params.merge({
              order_by: "id",
              order: "asc",
              per_page: 500,
              id_above: last_id,
              preferred_place_id: localization_place_id,
              locale: "en"
            }), { retry_delay: 2.0, retries: 30 })
            if !response || !response.results || response.results.length == 0
              beginning_or_more_results = false
              break
            end
            total_results ||= response.total_results
            response.results.each do |taxon|
              csv << [
                taxon["id"],
                taxon["name"],
                taxon["parent_id"],
                taxon["rank"],
                taxon["preferred_common_name"],
                taxon["wikipedia_url"]
              ]
            end
            last_id = response.results.last["id"]
            rows_written += response.results.length
            running_seconds = Time.now - start_time
            rows_per_second = ( rows_written / running_seconds ).round( 2 )
            estimated_remaining_time = ( ( total_results - rows_written ) / rows_per_second ).round( 2 )
            logger.debug "Taxa: #{rows_written} rows, #{rows_per_second}r/s, estimated #{estimated_remaining_time}s left"
          rescue Exception => e
            pp e
            beginning_or_more_results = false
            break
          end
        end
      end

      tmp_path
    end

    def observations_in_batches(params, preloads, options = {}, &block)
      batch_times = []
      max_id = Observation.maximum( :id )
      search_chunk_size = 500000
      chunk_start_id = 1
      if !params[:created_d1] && !params[:created_d2]
        # no date limits provided. We want to set a default upper limit of roughly when
        # the archive started exporting. Don't add created_d2 to the ES query, which
        # creates slower queries, rather check the date in Ruby
        max_observation_created = ( @generate_started_at || Time.now )
      end
      observations_start = Time.now
      # initial loop splits queries into batches by setting the search param
      # `id_below`. This make queries with very large result sets faster overall
      # with little overhead for small queries.
      while chunk_start_id <= max_id
        params[:min_id] = chunk_start_id
        params[:max_id] = chunk_start_id + search_chunk_size - 1
        Observation.search_in_batches( params, logger: logger ) do |batch|
          avg_batch_time = if batch_times.size > 0
            (batch_times.inject{|sum, num| sum + num}.to_f / batch_times.size).round(3)
          else
            0
          end
          avg_observation_time = avg_batch_time / ObservationSearch::SEARCH_IN_BATCHES_BATCH_SIZE
          msg = "Observation batch #{batch_times.size}"
          msg += " for #{options[:label]}" if options[:label]
          msg += " (avg batch: #{avg_batch_time}s, avg obs: #{avg_observation_time}s, obs in batch: #{batch.size})"
          if batch_times.size % 100 == 0
            logger.info msg
          else
            logger.debug msg
          end
          try_and_try_again( [PG::ConnectionBad, ActiveRecord::StatementInvalid], logger: logger ) do
            Observation.preload_associations(batch, preloads)
          end
          batch.each do |observation|
            if ( @opts[:community_taxon] && observation.community_taxon.blank? ||
                 max_observation_created && observation.created_at > max_observation_created )
              next
            end
            yield observation
          end
          batch_times << (Time.now - observations_start)
          observations_start = Time.now
        end
        chunk_start_id += search_chunk_size
      end
    end

    def make_archive(*args)
      fname = "dwca.zip"
      tmp_path = File.join(@opts[:work_path], fname)
      fnames = args.map{|f| File.basename(f)}
      system "cd #{@opts[:work_path]} && zip -D #{tmp_path} #{fnames.join(' ')}"
      tmp_path
    end
  end
end
