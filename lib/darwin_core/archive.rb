module DarwinCore
  class Archive

    def self.generate(opts = {})
      new(opts).generate
    end

    def initialize(opts = {})
      @opts = opts
      @opts[:path] ||= "dwca.zip"
      @opts[:core] ||= "occurrence"
      @opts[:metadata] ||= File.join(Rails.root, "app", "views", "observations", "gbif.eml.erb")
      @opts[:descriptor] ||= File.join(Rails.root, "app", "views", "observations", "gbif.descriptor.builder")
      @opts[:quality] ||= @opts[:quality_grade] || "research"
      @opts[:photo_licenses] ||= ["CC0", "CC-BY", "CC-BY-NC", "CC-BY-SA", "CC-BY-ND", "CC-BY-NC-SA", "CC-BY-NC-ND"]
      @opts[:licenses] ||= ["any"]
      @opts[:licenses] = @opts[:licenses].first if @opts[:licenses].size == 1
      @opts[:private_coordinates] ||= false
      @logger = @opts[:logger] || Rails.logger
      @logger.level = Logger::DEBUG if @opts[:debug]

      # Make a unique dir to put our files
      @work_path = Dir.mktmpdir
      FileUtils.mkdir_p @work_path, :mode => 0755

      @place = Place.find_by_id(@opts[:place].to_i) || Place.find_by_name(@opts[:place])
      logger.debug "Found place: #{@place}"
      @taxon = if @opts[:taxon].is_a?(::Taxon)
        @opts[:taxon]
      else
        ::Taxon.find_by_id(@opts[:taxon].to_i) || ::Taxon.active.find_by_name(@opts[:taxon])
      end
      logger.debug "Found taxon: #{@taxon}"
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
      @opts[:path]
    end

    def make_metadata
      m = DarwinCore::Metadata.new(@opts.merge(uri: FakeView.observations_url(observations_params)))
      tmp_path = File.join(@work_path, "metadata.eml.xml")
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
              :file_location => "media.csv",
              :terms => DarwinCore::EolMedia::TERMS
            }
          when "SimpleMultimedia"
            extensions << {
              row_type: "http://rs.gbif.org/terms/1.0/Multimedia",
              file_location: "images.csv",
              terms: DarwinCore::SimpleMultimedia::TERMS
            }
          when "ObservationFields"
            extensions << {
              row_type: "http://www.inaturalist.org/observation_fields",
              file_location: "observation_fields.csv",
              terms: DarwinCore::ObservationFields::TERMS
            }
          when "ProjectObservations"
            extensions << {
              row_type: "http://www.inaturalist.org/project_observations",
              file_location: "project_observations.csv",
              terms: DarwinCore::ProjectObservations::TERMS
            }
          when "User"
            extensions << {
              row_type: "http://www.inaturalist.org/user",
              file_location: "users.csv",
              terms: DarwinCore::User::TERMS
            }
          end
        end
      end
      d = DarwinCore::Descriptor.new(:core => @opts[:core], :extensions => extensions)
      tmp_path = File.join(@work_path, "meta.xml")
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
          paths << send("make_#{ext}_data")
        end
      end
      paths
    end

    def observations_params
      params = {}
      params[:license] = @opts[:licenses] unless @opts[:licenses].include?( "ignore" )
      params[:place_id] = @place.id if @place
      params[:taxon_id] = @taxon.id if @taxon
      params[:projects] = [@project.id] if @project
      params[:quality_grade] = @opts[:quality]
      params[:site_id] = @opts[:site_id]
      params[:created_d2] = ( @generate_started_at || Time.now ).iso8601
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
      headers = DarwinCore::Occurrence::TERM_NAMES
      fname = "observations.csv"
      tmp_path = File.join(@work_path, fname)
      fake_view = FakeView.new
      
      preloads = [
        { taxon: :ancestor_taxa }, 
        { user: :stored_preferences }, 
        :quality_metrics, 
        :identifications,
        { observations_places: :place }
      ]
      
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, logger: logger ) do
        CSV.open(tmp_path, 'w') do |csv|
          csv << headers
          observations_in_batches(observations_params, preloads, label: 'make_occurrence_data') do |o|
            benchmark(:obs) do
              o = DarwinCore::Occurrence.adapt(o, view: fake_view, private_coordinates: @opts[:private_coordinates])
              row = DarwinCore::Occurrence::TERMS.map do |field, uri, default, method|
                key = method || field
                benchmark( "obs_#{key}" ) { o.send( key ) }
              end
              benchmark(:obs_csv_row) { csv << row }
            end
          end
        end
      end
      
      tmp_path
    end

    def make_taxon_data
      headers = DarwinCore::Taxon::TERM_NAMES
      fname = "taxa.csv"
      tmp_path = File.join(@work_path, fname)
      licenses = @opts[:photo_licenses].map do |license_code|
        Photo.license_number_for_code(license_code)
      end
      
      scope = ::Taxon.
        select("DISTINCT ON (taxa.id) taxa.*").
        joins(:observations => {:observation_photos => :photo}).
        where("rank_level <= ? AND observation_photos.id IS NOT NULL AND photos.license IN (?)", ::Taxon::SPECIES_LEVEL, licenses)
      if @opts[:quality] == "research"
        scope = scope.where("observations.quality_grade = ?", Observation::RESEARCH_GRADE)
      elsif @opts[:quality] == "casual"
        scope = scope.where("observations.quality_grade = ?", Observation::CASUAL_GRADE)
      end
      
      scope = scope.where(@taxon.descendant_conditions[0]) if @taxon
      
      CSV.open(tmp_path, 'w') do |csv|
        csv << headers
        scope.find_each do |t|
          DarwinCore::Taxon.adapt(t)
          csv << DarwinCore::Taxon::TERMS.map{|field, uri, default, method| t.send(method || field)}
        end
      end
      
      tmp_path
    end

    def make_eol_media_data
      headers = DarwinCore::EolMedia::TERM_NAMES
      fname = "media.csv"
      tmp_path = File.join(@work_path, fname)
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
      end
      
      scope = scope.where(@taxon.descendant_conditions) if @taxon

      if @place
        scope = scope.joins("JOIN place_geometries ON place_geometries.place_id = #{@place.id}")
        scope = scope.where("ST_Intersects(place_geometries.geom, observations.private_geom)")
      end
      
      CSV.open(tmp_path, 'w') do |csv|
        csv << headers
        scope.find_each do |record|
          DarwinCore::EolMedia.adapt(record)
          csv << DarwinCore::EolMedia::TERMS.map{|field, uri, default, method| record.send(method || field)}
        end
      end
      
      tmp_path
    end

    def make_simple_multimedia_data
      headers = DarwinCore::SimpleMultimedia::TERM_NAMES
      fname = "images.csv"
      tmp_path = File.join(@work_path, fname)
      
      params = observations_params
      unless @opts[:photo_licenses].include?( "ignore")
        if @opts[:photo_licenses] && !@opts[:photo_licenses].include?( "any" )
          params[:photo_license] = @opts[:photo_licenses].map(&:downcase)
        end
        params[:photo_license] ||= 'any'
      end
      params[:has] = [params[:has], 'photos'].flatten.compact
      preloads = [{observation_photos: {photo: :user}}]

      start_time = @generate_started_at || Time.now
      
      try_and_try_again( Elasticsearch::Transport::Transport::Errors::ServiceUnavailable, logger: logger ) do
        CSV.open(tmp_path, 'w') do |csv|
          csv << headers
          observations_in_batches(params, preloads, label: 'make_simple_multimedia_data') do |observation|
            observation.observation_photos.sort_by{|op| op.position || op.id }.each do |op|
              # If ES is out of sync with the DB, the photo might no longer exist
              next if op.nil?
              next if op.created_at.nil?
              next if op.photo.nil?
              next unless op.created_at <= start_time
              DarwinCore::SimpleMultimedia.adapt(op.photo, observation: observation, core: @opts[:core])
              csv << DarwinCore::SimpleMultimedia::TERMS.map{|field, uri, default, method| op.photo.send(method || field)}
            end
          end
        end
      end
      
      tmp_path
    end

    def make_observation_fields_data
      headers = DarwinCore::ObservationFields::TERM_NAMES
      fname = "observation_fields.csv"
      tmp_path = File.join(@work_path, fname)
      
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
      
      tmp_path
    end

    def make_project_observations_data
      headers = DarwinCore::ProjectObservations::TERM_NAMES
      fname = "project_observations.csv"
      tmp_path = File.join(@work_path, fname)
      
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
      
      tmp_path
    end

    def make_user_data
      headers = DarwinCore::User::TERM_NAMES
      fname = "users.csv"
      tmp_path = File.join(@work_path, fname)
      
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
      
      tmp_path
    end

    def observations_in_batches(params, preloads, options = {}, &block)
      batch_times = []
      Observation.search_in_batches(params) do |batch|
        start = Time.now
        avg_batch_time = if batch_times.size > 0
          (batch_times.inject{|sum, num| sum + num}.to_f / batch_times.size).round(3)
        else
          0
        end
        avg_observation_time = avg_batch_time / 500
        msg = "Observation batch #{batch_times.size}"
        msg += " for #{options[:label]}" if options[:label]
        msg += " (avg batch: #{avg_batch_time}s, avg obs: #{avg_observation_time}s)"
        logger.debug msg
        try_and_try_again( [PG::ConnectionBad, ActiveRecord::StatementInvalid], logger: logger ) do
          Observation.preload_associations(batch, preloads)
        end
        batch.each do |observation|
          yield observation
        end
        batch_times << (Time.now - start)
      end
    end

    def make_archive(*args)
      fname = "dwca.zip"
      tmp_path = File.join(@work_path, fname)
      fnames = args.map{|f| File.basename(f)}
      system "cd #{@work_path} && zip -D #{tmp_path} #{fnames.join(' ')}"
      tmp_path
    end
  end
end
