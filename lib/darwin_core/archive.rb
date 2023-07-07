module DarwinCore
  class Archive

    OBS_BASED_EXTENSIONS = [
      :occurrence,
      :simple_multimedia,
      :observation_fields,
      :resource_relationships,
      :project_observations,
      :user
    ]

    def self.generate(opts = {})
      new(opts).generate
    end

    def initialize(opts = {})
      @opts = opts.clone.symbolize_keys
      @opts[:path] ||= "dwca.zip"
      @opts[:core] ||= DarwinCore::Cores::OCCURRENCE
      @opts[:extensions] = [@opts[:extensions]].flatten.compact
      @opts[:metadata] ||= if @opts[:core] == DarwinCore::Cores::OCCURRENCE
        File.join( "observations", "dwc" )
      else
        File.join( "taxa", "dwc" )
      end
      @opts[:descriptor] ||= File.join("observations", "dwc_descriptor")
      @opts[:quality] ||= @opts[:quality_grade] || "research"
      @opts[:photo_licenses] ||= ["CC0", "CC-BY", "CC-BY-NC", "CC-BY-SA", "CC-BY-ND", "CC-BY-NC-SA", "CC-BY-NC-ND"]
      @opts[:media_licenses] = @opts[:photo_licenses].map(&:downcase)
      @opts[:licenses] ||= ["any"]
      @opts[:licenses] = @opts[:licenses].first if @opts[:licenses].size == 1
      @opts[:private_coordinates] ||= false
      @opts[:taxon_private_coordinates] ||= false
      @opts[:photographed_taxa] ||= false
      @opts[:processes] ||= 1
      @logger = @opts[:logger] || Rails.logger
      @logger.level = Logger::DEBUG if @opts[:debug]

      # Make a unique dir to put our files
      @opts[:work_path] = Dir.mktmpdir
      FileUtils.mkdir_p @opts[:work_path], :mode => 0755
      logger.debug "Using working directory: #{@opts[:work_path]}"

      @place = Place.find_by_id(@opts[:place].to_i) || Place.find_by_name(@opts[:place])
      logger.debug "Found place: #{@place}"
      @taxa = [@opts[:taxon]].flatten.compact.map do |taxon|
        if taxon.is_a?( ::Taxon )
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

    def extension_paths
      @extension_paths || { }
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
        paths += [make_api_all_taxon_data]
      end
      archive_path = make_archive( *paths )
      logger.debug "Archive: #{archive_path}"
      FileUtils.mv( archive_path, @opts[:path] )
      logger.info "Archive generated: #{@opts[:path]}"
      if @benchmarks
        logger.info %w(BENCHMARK TOTAL AVG).map{|h| h.ljust( 30 )}.join( " " )
        @benchmarks.each do |key, times|
          logger.info [key, times.sum.round(5), (times.sum.to_f / times.size).round(5)].map{|h| h.to_s.ljust( 30 )}.join( " " )
        end
      end
      upload_to_aws_s3
      @opts[:path]
    end

    def make_metadata
      metadata_observation_params = observations_params
      if !metadata_observation_params[:created_d2]
        metadata_observation_params[:created_d2] = Time.now
      end
      m = DarwinCore::Metadata.new( @opts.merge(
        observations_params: metadata_observation_params,
        template: @opts[:metadata]
      ) )
      tmp_path = File.join( @opts[:work_path], "metadata.eml.xml" )
      File.open( tmp_path, "w" ) do | f |
        f << m.render
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
          when "ResourceRelationships"
            extensions << {
              row_type: "http://rs.tdwg.org/dwc/terms/ResourceRelationship",
              files: ["resource_relationships.csv"],
              terms: DarwinCore::ResourceRelationship::TERMS
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
      d = DarwinCore::Descriptor.new(
        template: @opts[:descriptor],
        handlers: [:builder],
        formats: [:xml],
        core: @opts[:core],
        extensions: extensions,
        ala: @opts[:ala],
        include_uuid: @opts[:include_uuid]
      )
      tmp_path = File.join( @opts[:work_path], "meta.xml" )
      File.open( tmp_path , "w" ) do |f|
        f << d.render
      end
      tmp_path
    end

    def make_data
      @generate_started_at ||= Time.now
      @extension_paths = { }
      core_and_extensions = [@opts[:core]] + @opts[:extensions]
      core_and_extensions.map!{ |ext| ext.underscore.downcase.to_sym }
      ( obs_based_extensions, custom_extensions ) = core_and_extensions.partition do |ext|
        DarwinCore::Archive::OBS_BASED_EXTENSIONS.include?( ext )
      end

      if obs_based_extensions.any?
        obs_based_extension_info = { }
        preloads = []
        obs_based_extensions.each do |ext|
          logger.info "Preparing #{ext} extension..."
          obs_based_extension_info[ext] = send("make_#{ext}_file")
          preloads += obs_based_extension_info[ext][:preloads]
          @extension_paths[ext] = obs_based_extension_info[ext][:path]
        end
        observation_ids_written = { }
        process_observations(
          observations_params,
          preloads,
          @opts.merge( {
            label: "obs_based_extensions"
          } )
        ) do |batch|
          batch = batch.filter{ |o| !observation_ids_written[o.id] }
          obs_based_extensions.each do |ext|
            extension_file = CSV.open( @extension_paths[ext], "a" )
            send( "write_#{ext}_data", batch, extension_file )
            extension_file.close
          end
          batch.each do |o|
            observation_ids_written[o.id] = true
          end
        end
      end

      custom_extensions.each do |ext|
        logger.info "Making #{ext} extension..."
        @extension_paths[ext] = send("make_#{ext}_data")
      end
      @extension_paths.values
    end

    def observations_params
      params = {}
      params[:license] = [@opts[:licenses]].flatten.compact.join( "," ) unless @opts[:licenses].include?( "ignore" )
      params[:place_id] = @place.id if @place
      params[:taxon_ids] = @taxa.map(&:id) if @taxa
      params[:projects] = [@project.id] if @project
      params[:quality_grade] = @opts[:quality] === "verifiable" ? "research,needs_id" : @opts[:quality]
      params[:site_id] = @opts[:site_id]
      params[:d1] = @opts[:d1]
      params[:d2] = @opts[:d2]
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
      if @opts[:with_annotations]
        recognized_term_ids = DarwinCore::Occurrence::ANNOTATION_CONTROLLED_TERM_MAPPING.values.map do |l|
          ControlledTerm.first_term_by_label( l )
        end.compact.map( &:id )
        params[:term_id] = recognized_term_ids.join( "," ) if recognized_term_ids.any?
      elsif @opts[:with_controlled_terms]
        term_ids = @opts[:with_controlled_terms].map do |term|
          ControlledTerm.first_term_by_label( term.underscore.humanize )
        end.compact.map( &:id )
        params[:term_id] = term_ids.join( "," ) if term_ids.any?
      end
      if @opts[:with_controlled_values]
        term_value_ids = @opts[:with_controlled_values].map do |term|
          ControlledTerm.first_term_by_label( term.underscore.humanize )
        end.compact.map( &:id )
        params[:term_value_id] = term_value_ids.join( "," ) if term_value_ids.any?
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

    def make_occurrence_file
      @occurrence_terms = DarwinCore::Occurrence::TERMS.dup
      if @opts[:ala]
        @occurrence_terms += DarwinCore::Occurrence::ALA_EXTRA_TERMS
      end
      if @opts[:include_uuid]
        @occurrence_terms += [DarwinCore::Occurrence::OTHER_CATALOGUE_NUMBERS_TERM]
      end
      headers = DarwinCore::Occurrence.term_names( @occurrence_terms )
      fname = "observations.csv"
      tmp_path = File.join(@opts[:work_path], fname)

      preloads = [
        :taxon,
        { user: [:stored_preferences, :provider_authorizations] },
        :quality_metrics, 
        { identifications: { user: [:provider_authorizations] } },
        { observations_places: :place },
        { annotations: { controlled_value: [:labels], votes_for: {} } },
        { site: :place }
      ]
      if @opts[:community_taxon]
        preloads << :community_taxon
      end
      file = CSV.open( tmp_path, "w" )
      file << headers
      file.close
      { path: tmp_path, preloads: preloads }
    end

    def write_occurrence_data( observations, csv )
      @fake_view ||= FakeView.new
      taxon_ranked_ancestors = DarwinCore::Archive.lookup_taxa_for_obs_batch( observations )
      observations.each do |observation|
        benchmark(:obs) do
          private_coordinates = if @opts[:private_coordinates]
            true
          elsif @opts[:taxon_private_coordinates]
            [nil, Observation::OPEN].include?( observation.geoprivacy )
          end
          observation = DarwinCore::Occurrence.adapt(observation,
            view: @fake_view,
            private_coordinates: private_coordinates,
            community_taxon: @opts[:community_taxon]
          )
          if observation.dwc_taxon
            observation.set_ranked_ancestors( taxon_ranked_ancestors[observation.dwc_taxon.id] )
          end
          row = @occurrence_terms.map do |field, uri, default, method|
            key = method || field
            benchmark( "obs_#{key}" ) { observation.send( key ) }
          end
          benchmark(:obs_csv_row) { csv << row }
        end
      end
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
          scope = scope.where("observations.quality_grade = ?", Observation::CASUAL)
        elsif @opts[:quality] == "verifiable"
          scope = scope.where("observations.quality_grade IN (?, ?)", Observation::RESEARCH_GRADE, Observation::NEEDS_ID)
        end
      else
        scope = scope.where( "is_active" )
      end

      CSV.open(tmp_path, 'w') do |csv|
        csv << headers
        if @taxa.blank?
          scope.includes( :source ).find_in_batches( batch_size: 1000 ) do |batch|
            taxon_ranked_ancestors = DarwinCore::Archive.lookup_taxa_ancestors(
              batch.map( &:id ), batch.map( &:ancestry ).map{ |a| a.try( :split, "/" ) }.flatten.uniq.compact
            )
            batch.each do |t|
              DarwinCore::Taxon.adapt(t)
              t.set_ranked_ancestors( taxon_ranked_ancestors[t.id] )
              csv << DarwinCore::Taxon::TERMS.map{|field, uri, default, method| t.send(method || field)}
            end
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
      tmp_path
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
        scope = scope.where("observations.quality_grade = ?", Observation::CASUAL)
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
      tmp_path
    end

    def make_simple_multimedia_file
      headers = DarwinCore::SimpleMultimedia::TERM_NAMES
      fname = "media.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      
      params = observations_params
      preloads = [ {
        observation_photos: {
          photo: [
            :file_prefix, :file_extension, :user, :flags, :photo_metadata
          ] }
        },
        {
          observation_sounds: {
            sound: :user
          }
        }
      ]
      file = CSV.open( tmp_path, "w" )
      file << headers
      file.close
      { path: tmp_path, preloads: preloads }
    end

    def write_simple_multimedia_data( observations, csv )
      @generate_started_at ||= Time.now
      observations.each do |observation|
        return if observation.observation_photos.blank? && observation.observation_sounds.blank?
        begin
          observation.observation_photos.sort_by{|op| op.position || op.id }.each do |op|
            # If ES is out of sync with the DB, the photo might no longer exist
            next if op.nil?
            next if op.created_at.nil?
            next if op.photo.nil?
            next unless op.created_at <= @generate_started_at
            if !@opts[:media_licenses].include?( "ignore" )
              next if op.photo.all_rights_reserved?
              next unless @opts[:media_licenses].include?( op.photo.license_code.to_s.downcase )
            end
            DarwinCore::SimpleMultimedia.adapt(op.photo, observation: observation, core: @opts[:core])
            csv << DarwinCore::SimpleMultimedia::TERMS.map{|field, uri, default, method| op.photo.send(method || field)}
          end
          observation.observation_sounds.sort_by(&:id).each do |os|
            next if os.nil?
            next if os.created_at.nil?
            next if os.sound.nil?
            next unless os.sound.is_a?( LocalSound ) # Soundcloud sounds don't come with stable file URLs we can share
            next unless os.created_at <= @generate_started_at
            if !@opts[:media_licenses].include?( "ignore" )
              next if os.sound.all_rights_reserved?
              next unless @opts[:media_licenses].include?( os.sound.license_code.to_s.downcase )
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

    def make_observation_fields_file
      headers = DarwinCore::ObservationFields::TERM_NAMES
      fname = "observation_fields.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      preloads = [ { observation_field_values: :observation_field } ]
      file = CSV.open( tmp_path, "w" )
      file << headers
      file.close
      { path: tmp_path, preloads: preloads }
    end

    def write_observation_fields_data( observations, csv )
      @generate_started_at ||= Time.now
      observations.each do |observation|
        observation.observation_field_values.each do |ofv|
          next unless ofv.created_at <= @generate_started_at
          DarwinCore::ObservationFields.adapt(ofv, observation: observation, core: @opts[:core])
          csv << DarwinCore::ObservationFields::TERMS.map{|field, uri, default, method| ofv.send(method || field)}
        end
      end
    end

    def make_resource_relationships_file
      headers = DarwinCore::ResourceRelationship::TERM_NAMES
      fname = "resource_relationships.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      preloads = [ { observation_field_values: :observation_field } ]
      file = CSV.open( tmp_path, "w" )
      file << headers
      file.close
      { path: tmp_path, preloads: preloads }
    end

    def write_resource_relationships_data( observations, csv )
      @generate_started_at ||= Time.now
      observations.each do |observation|
        # fields must have datatype "taxon", values must have a user and the value must be numeric
        observation.observation_field_values.select do |ofv|
          ofv.observation_field.datatype === "taxon" &&
          ofv.user &&
          ActiveModel::Validations::NumericalityValidator::INTEGER_REGEX.match?( ofv.value )
        end.each do |ofv|
          next unless ofv.created_at <= @generate_started_at
          DarwinCore::ResourceRelationship.adapt( ofv, observation: observation, core: @opts[:core] )
          csv << DarwinCore::ResourceRelationship::TERMS.map{ |field, uri, default, method| ofv.send( method || field ) }
        end
      end
    end

    def make_project_observations_file
      headers = DarwinCore::ProjectObservations::TERM_NAMES
      fname = "project_observations.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      preloads = [ { project_observations: :project } ]
      file = CSV.open( tmp_path, "w" )
      file << headers
      file.close
      { path: tmp_path, preloads: preloads }
    end

    def write_project_observations_data( observations, csv )
      @generate_started_at ||= Time.now
      observations.each do |observation|
        observation.project_observations.each do |po|
          next unless po.created_at <= @generate_started_at
          DarwinCore::ProjectObservations.adapt(po, core: @opts[:core])
          csv << DarwinCore::ProjectObservations::TERMS.map{|field, uri, default, method| po.send(method || field)}
        end
      end
    end

    def make_user_file
      headers = DarwinCore::User::TERM_NAMES
      fname = "users.csv"
      tmp_path = File.join(@opts[:work_path], fname)
      preloads = [ :user ]
      file = CSV.open( tmp_path, "w" )
      file << headers
      file.close
      { path: tmp_path, preloads: preloads }
    end

    def write_user_data( observations, csv )
      observations.each do |observation|
        DarwinCore::User.adapt( observation.user, core: @opts[:core], observation: observation )
        csv << DarwinCore::User::TERMS.map{|field, uri, default, method| observation.user.send(method || field)}
      end
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

    def self.partition_range( start_id, max_id, partitions = 1 )
      partition_start_id = start_id
      partition_ranges = []
      (1..partitions).each do |i|
        partition_end_id = ( max_id * i ) / partitions
        partition_ranges << { start_id: partition_start_id, end_id: partition_end_id }
        partition_start_id = partition_end_id + 1
      end
      partition_ranges
    end

    def process_observations( params, preloads, options = {}, &block )
      max_id = Observation.maximum( :id )
      if options[:processes] > 1
        # use the Parallel gem if more than one process was requested
        range_partitions = DarwinCore::Archive.partition_range( 1, max_id, options[:processes] )
        Parallel.each( range_partitions, in_processes: options[:processes] ) do |range|
          observations_in_batches(
            params,
            preloads,
            range[:start_id],
            range[:end_id],
            options,
            &block
          )
        end
      else
        observations_in_batches(
          params,
          preloads,
          1,
          max_id,
          options,
          &block
        )
      end
    end

    def observations_in_batches( params, preloads, start_id, end_id, options = {} )
      batch_times = []
      search_chunk_size = 200000
      chunk_start_id = 1
      last_seen_observation_id = nil
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
      chunk_start_id = start_id
      while chunk_start_id <= end_id
        params[:min_id] = chunk_start_id
        params[:max_id] = [chunk_start_id + search_chunk_size - 1, end_id].min
        try_and_try_again( [
                  Elasticsearch::Transport::Transport::Errors::ServiceUnavailable,
                  Elasticsearch::Transport::Transport::Errors::TooManyRequests], sleep: 1, tries: 10, logger: logger ) do
          Observation.search_in_batches( params.merge(
            per_page: 1000
          ), logger: logger ) do |batch|
            avg_batch_time = if batch_times.size > 0
              (batch_times.inject{|sum, num| sum + num}.to_f / batch_times.size).round(3)
            else
              0
            end
            avg_observation_time = avg_batch_time / ObservationSearch::SEARCH_IN_BATCHES_BATCH_SIZE
            msg = "Observation batch #{batch_times.size}"
            msg += " for #{options[:label]}" if options[:label]
            msg += " (avg batch: #{avg_batch_time}s, avg obs: #{avg_observation_time}s, obs in batch: #{batch.size})"
            if batch_times.size % 20 == 0
              logger.info msg
              logger.flush if logger.respond_to?( :flush )
            else
              logger.debug msg
            end
            try_and_try_again( [PG::ConnectionBad, ActiveRecord::StatementInvalid], logger: logger ) do
              Observation.preload_associations(batch, preloads)
            end
            filtered_obs = batch.select do |observation|
              ! ( ( @opts[:community_taxon] && observation.community_taxon.blank? ) ||
                  ( max_observation_created && observation.created_at > max_observation_created ) ||
                  ( last_seen_observation_id && observation.id <= last_seen_observation_id ) )
            end
            batch.uniq!
            batch.sort!
            if last_obs = filtered_obs.last
              last_seen_observation_id = last_obs.id
            end
            yield filtered_obs
            batch_times << (Time.now - observations_start)
            observations_start = Time.now
          end
        end

        chunk_start_id += search_chunk_size
      end
    end

    def make_archive( *args )
      fname = "dwca.zip"
      tmp_path = File.join( @opts[:work_path], fname )
      fnames = args.map {| f | File.basename( f ) }
      cmd = "cd #{@opts[:work_path]} && zip -D #{tmp_path} #{fnames.join( ' ' )}"
      logger.debug( "Running #{cmd}")
      system cmd
      tmp_path
    end

    # given an array of observations, return a hash containing name and ancestry
    # information about the observations' taxa
    def self.lookup_taxa_for_obs_batch( observations )
      taxon_ids = observations.map{ |o| [o.taxon_id, o.community_taxon_id] }.flatten.uniq.compact
      ancestor_taxon_ids = ::Taxon.where( id: taxon_ids ).pluck( :ancestry ).
        map{ |a| a.try( :split, "/" ) }.flatten.uniq.compact
      lookup_taxa_ancestors( taxon_ids, ancestor_taxon_ids )
    end

    def self.lookup_taxa_ancestors( taxon_ids, ancestor_taxon_ids )
      cached_taxa = { }
      ::Taxon.where( id: ( taxon_ids + ancestor_taxon_ids ).uniq ).
        pluck( :id, :name, :rank, :ancestry ).each do |row|
        ( taxon_id, name, rank, ancestry ) = row
        ancestor_ids = ancestry.blank? ? [] : ancestry.split( "/" ).map( &:to_i )
        cached_taxa[taxon_id] = {
          name: name,
          rank: rank,
          parent_id: ancestor_ids.last || 0,
          ancestor_ids: ancestor_ids
         }
      end
      taxa_ranked_ancestors = Hash[taxon_ids.map do |taxon_id|
        [taxon_id, generate_ranked_ancestors( taxon_id, cached_taxa )]
      end]
      return taxa_ranked_ancestors
    end

    # given a taxon_id and cached taxon information from #lookup_taxa_for_obs_batch,
    # return a hash of each rank and taxon name in the taxon's ancestry
    def self.generate_ranked_ancestors( taxon_id, cached_taxa = { } )
      ranked_ancestors = { }
      taxon = cached_taxa[taxon_id]
      return ranked_ancestors unless taxon
      taxon[:ancestor_ids].each do |ancestor_id|
        if ancestor = cached_taxa[ancestor_id]
          # first instance of rank takes priority
          ranked_ancestors[( ancestor[:rank] + "_name" ).to_sym] ||= ancestor[:name]
        end
      end
      # include itself
      ranked_ancestors[( taxon[:rank] + "_name" ).to_sym] ||= taxon[:name]
      ranked_ancestors
    end

    def upload_to_aws_s3
      return unless @opts[:aws_s3_path]
      s3_config = YAML.load_file( File.join( Rails.root, "config", "s3.yml" ) )
      client = ::Aws::S3::Client.new(
        access_key_id: s3_config["access_key_id"],
        secret_access_key: s3_config["secret_access_key"],
        region: CONFIG.s3_region
      )
      resource = Aws::S3::Resource.new( client: client )
      bucket = resource.bucket( CONFIG.s3_bucket )
      object = bucket.object( @opts[:aws_s3_path] )
      object.upload_file( @opts[:path], {
        acl: "public-read",
        content_encoding: "zip"
      } )
    end

  end
end
