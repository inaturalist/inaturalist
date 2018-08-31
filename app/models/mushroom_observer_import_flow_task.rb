class MushroomObserverImportFlowTask < FlowTask

  validate :validate_unique_hash
  before_validation :set_unique_hash

  def validate_unique_hash
    return unless unique_hash && !finished_at
    scope = MushroomObserverImportFlowTask.
      where(finished_at: nil).
      where(unique_hash: unique_hash)
    scope = scope.where("id != ?", id) if id
    return unless scope.count > 0
    errors.add(:base, :api_key_in_use)
  end

  def set_unique_hash
    return unless api_key
    self.unique_hash = { api_key: api_key }
  end

  def run
    update_attributes(finished_at: nil, error: nil, exception: nil)
    log "Importing observations from Mushroom Observer for #{user}"
    page = 1
    errors = {}
    loop do
      results = get_results_xml( page: page )
      break if results.blank?
      results.each do |result|
        transaction do
          o = observation_from_result( result )
          unless o && o.save
            mo_url = result[:url].gsub( "https", "http" )
            errors[mo_url] = o.errors.full_messages.to_sentence
            clear_warnings_for_url( mo_url )
          end
        end
      end
      page += 1
    end
    log "Finished importing observations from Mushroom Observer for #{user}"
    Emailer.moimport_finished( self, errors, @warnings ).deliver_now
  rescue Exception => e
    exception_string = [ e.class, e.message ].join(" :: ")
    logger.error "#{self.class.name} #{id}: Error: #{exception_string}" if @debug
    update_attributes(
      finished_at: Time.now,
      error: "Error",
      exception: [ exception_string, e.backtrace ].join("\n")
    )
    Emailer.moimport_finished( self, errors, @warnings ).deliver_now
    false
  end

  def log( msg )
    if options[:logger] == "stdout"
      puts
      puts "[INFO] #{msg}"
      puts
    else
      Rails.logger.info "[INFO] #{msg}"
    end
  end

  def get_results_xml( options = {} )
    user_id = mo_user_id( options[:api_key] )
    page = options[:page] || 1
    Nokogiri::XML( open( "https://mushroomobserver.org/api/observations?user=#{user_id}&detail=high&page=#{page}" ) ).search( "result" )
  end

  def mo_user_id( for_api_key = nil )
    unless @mo_user_id
      for_api_key ||= api_key
      xml = Nokogiri::XML( open( "https://mushroomobserver.org/api/api_keys?api_key=#{for_api_key}" ) )
      @mo_user_id = xml.at( "response/user" )[:id]
    end
    @mo_user_id
  end

  def mo_user_name( for_api_key = nil )
    unless @mo_user_name
      user_id = mo_user_id( for_api_key )
      xml = Nokogiri::XML( open( "https://mushroomobserver.org/api/users?id=#{user_id}&detail=high" ) )
      @mo_user_name = xml.at( "login_name" ).text
    end
    @mo_user_name
  end

  def api_key
    return nil unless inputs && inputs.first && inputs.first.extra
    @api_key ||= inputs.first.extra[:api_key]
  end

  def warn( url, msg )
    log msg
    @warnings ||= {}
    @warnings[url] ||= []
    @warnings[url] << msg
  end

  def clear_warnings_for_url( url )
    @warnings ||= {}
    @warnings.delete url
  end

  def images_from_result( result )
    primary_image = result.at( "primary_image" )
    [primary_image, result.search( "> images image" )].compact.flatten
  end

  def observation_from_result( result, options = {} )
    mo_url = result[:url].gsub( "https", "http" )
    log "working on result #{mo_url}"
    if ( is_collection_location = result.at( "is_collection_location" ) ) && is_collection_location[:value] == "false"
      warn( result[:url], "Obs not from collection location")
      return nil
    end
    existing = Observation.by( user ).joins(:observation_field_values).
      where(
        "observation_field_values.observation_field_id = ? AND value = ?",
        mo_url_observation_field,
        mo_url
      ).first
    if existing
      log "Found existing for #{mo_url}: #{existing}"
      return existing
    end
    o = Observation.new( user: user )
    o.observation_field_values.build( observation_field: mo_url_observation_field, value: mo_url )
    if location = result.at_css( "> location" )
      o.place_guess = location.at( "name" ).text
      swlat = location.at( "latitude_south" ).text.to_f
      swlng = location.at( "longitude_west" ).text.to_f
      nelat = location.at( "latitude_north" ).text.to_f
      nelng = location.at( "longitude_east" ).text.to_f
      o.latitude = swlat + ( ( nelat - swlat ) / 2 )
      o.longitude = swlng + ( ( nelng - swlng ) / 2 )
      o.positional_accuracy = lat_lon_distance_in_meters(o.latitude, o.longitude, nelat, nelng)
    end
    if consensus_name = result.at( "consensus_name" )
      name = consensus_name.at( "name" ).text
      begin
        taxon = Taxon.single_taxon_for_name( name, iconic_taxa: [
          Taxon::ICONIC_TAXA_BY_NAME["Fungi"],
          Taxon::ICONIC_TAXA_BY_NAME["Protozoa"]
        ] )
        taxon ||= Taxon.import( name, ancestor: Taxon::ICONIC_TAXA_BY_NAME["Fungi"] ) rescue nil
        if taxon && taxon.persisted?
          o.taxon = Taxon.find_by_id( taxon.id )
          if taxon.name != name
            warn( mo_url, "Name mismatch, #{name} on MO, #{taxon.name} on iNat" )
          end
        end
      rescue ActiveRecord::AssociationTypeMismatch
        warn( mo_url, "Failed to import a new taxon for #{name}")
      end
      o.species_guess = name
      o.observation_field_values.build( observation_field: mo_name_observation_field, value: [
        name,
        consensus_name.at( "author" ).try(:text)
      ].compact.join(" ") )
    end
    if date = result.at_css( "> date" )
      o.observed_on_string = date.text
    end
    if notes = result.at_css( "> notes" )
      if notes.text =~ /\:Other/
        o.description = notes.text[/&gt;&quot;(.+)&quot;\}/, 1]
      elsif notes.text != "<p>{}</p>"
        o.description = notes.text
      end
    end
    if !options[:skip_images] && ( images = images_from_result( result ) ) && images.size > 0
      images.each do |image|
        image_url = "https://mushroomobserver.nyc3.digitaloceanspaces.com/orig/#{image[:id]}.jpg"
        lp = LocalPhoto.new( user: user )
        begin
          log "getting image from #{image_url}"
          io = open( URI.parse( image_url ) )
          Timeout::timeout(10) do
            lp.file = (io.base_uri.path.split('/').last.blank? ? nil : io)
          end
        rescue => e
          begin
            image_url = "https://images.mushroomobserver.org/orig/#{image[:id]}.jpg"
            log "getting image from #{image_url}"
            io = open( URI.parse( image_url ) )
            Timeout::timeout(10) do
              lp.file = (io.base_uri.path.split('/').last.blank? ? nil : io)
            end
          rescue => e
            warn( mo_url, "Failed to download #{image_url}")
            next
          end
        end
        if image_license = image.at( "license")
          lp.license = case image_license[:url]
          when /by-nc-sa\// then Photo::CC_BY_NC_SA
          when /by-nc-nd\// then Photo::CC_BY_NC_ND
          when /by-sa\// then Photo::CC_BY_SA
          when /by-nd\// then Photo::CC_BY_ND
          when /by\// then Photo::CC_BY
          when /publicdomain\// then Photo::PD
          end
        end 
        o.observation_photos.build( photo: lp )
      end
    end
    o
  end

  def mo_url_observation_field
    unless @mo_url_observation_field
      @mo_url_observation_field = ObservationField.find_by_name( "Mushroom Observer URL" )
      @mo_url_observation_field ||= ObservationField.create!(
        name: "Mushroom Observer URL",
        datatype: ObservationField::TEXT,
        description: "URL of this record on https://mushroomobserver.org"
      )
    end
    @mo_url_observation_field
  end

  def mo_name_observation_field
    unless @mo_name_observation_field
      @mo_name_observation_field = ObservationField.find_by_name( "Mushroom Observer Consensus Name" )
      @mo_name_observation_field ||= ObservationField.create!(
        name: "Mushroom Observer Consensus Name",
        datatype: ObservationField::TEXT,
        description: "Consensus taxon name for this record on https://mushroomobserver.org"
      )
    end
    @mo_name_observation_field
  end
end
