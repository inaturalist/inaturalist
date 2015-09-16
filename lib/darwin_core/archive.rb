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
      @opts[:quality] ||= "research"
      @opts[:photo_licenses] ||= ["CC-BY", "CC-BY-NC", "CC-BY-SA", "CC-BY-ND", "CC-BY-NC-SA", "CC-BY-NC-ND"]
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
        ::Taxon.find_by_id(@opts[:taxon].to_i) || ::Taxon.find_by_name(@opts[:taxon])
      end
      logger.debug "Found taxon: #{@taxon}"
      logger.debug "Photo licenses: #{@opts[:photo_licenses].inspect}"
    end

    def logger
      @logger || Rails.logger
    end

    def generate
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
      @opts[:path]
    end

    def make_metadata
      m = DarwinCore::Metadata.new(@opts)
      tmp_path = File.join(@work_path, "metadata.eml.xml")
      open(tmp_path, 'w') do |f|
        f << m.render(:file => @opts[:metadata])
      end
      tmp_path
    end

    def make_descriptor
      extensions = []
      if @opts[:extensions]
        if @opts[:extensions].detect{|e| e == "EolMedia"}
          extensions << {
            :row_type => "http://eol.org/schema/media/Document",
            :file_location => "media.csv",
            :terms => DarwinCore::EolMedia::TERMS
          }
        elsif @opts[:extensions].detect{|e| e == "SimpleMultimedia"}
          extensions << {
            row_type: "http://rs.gbif.org/terms/1.0/Multimedia",
            file_location: "images.csv",
            terms: DarwinCore::SimpleMultimedia::TERMS
          }
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

    def observations_scope
      scope = Observation.where("observations.license IS NOT NULL")
      if @opts[:quality] == "research"
        scope = scope.where("quality_grade = ?", Observation::RESEARCH_GRADE)
      elsif @opts[:quality] == "casual"
        scope = scope.where("quality_grade = ?", Observation::CASUAL_GRADE)
      end
      scope = scope.of(@taxon) if @taxon
      scope = scope.in_place(@place) if @place
      scope
    end

    def make_occurrence_data
      headers = DarwinCore::Occurrence::TERM_NAMES
      fname = "observations.csv"
      tmp_path = File.join(@work_path, fname)
      fake_view = FakeView.new
      
      scope = observations_scope.
        includes(:taxon, {:user => :stored_preferences}, :quality_metrics, :identifications)
      
      start = Time.now
      CSV.open(tmp_path, 'w') do |csv|
        csv << headers
        scope.find_each do |o|
          next unless o.user.prefers_gbif_sharing?
          o = DarwinCore::Occurrence.adapt(o, :view => fake_view)
          csv << DarwinCore::Occurrence::TERMS.map do |field, uri, default, method| 
            o.send(method || field)
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
      licenses = @opts[:photo_licenses].map do |license_code|
        Photo.license_number_for_code(license_code)
      end
      
      scope = observations_scope.
        joins(:taxon, {observation_photos: {photo: :user}}).
        includes(observation_photos: {photo: :user}).
        where("photos.license IN (?)", licenses)
      
      CSV.open(tmp_path, 'w') do |csv|
        csv << headers
        scope.find_each do |observation|
          observation.observation_photos.each do |op|
            DarwinCore::SimpleMultimedia.adapt(op.photo, observation: observation, core: @opts[:core])
            csv << DarwinCore::SimpleMultimedia::TERMS.map{|field, uri, default, method| op.photo.send(method || field)}
          end
        end
      end
      
      tmp_path
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
