class MushroomObserverImportFlowTask < FlowTask

  validate :validate_unique_hash
  validate :api_key_present
  before_validation :set_unique_hash

  attr_accessor :warnings

  class MushroomObserverImportFlowTaskError < StandardError; end
  class TooManyRequestsError < MushroomObserverImportFlowTaskError; end
  class TimeoutError < MushroomObserverImportFlowTaskError; end
  class ForbiddenError < MushroomObserverImportFlowTaskError; end

  def validate_unique_hash
    return unless unique_hash && !finished_at
    scope = MushroomObserverImportFlowTask.
      where(finished_at: nil).
      where(unique_hash: unique_hash)
    scope = scope.where("id != ?", id) if id
    return unless scope.count > 0
    errors.add(:base, :api_key_in_use)
    true
  end

  def api_key_present
    if inputs.first.blank? || inputs.first.extra.blank? || inputs.first.extra.symbolize_keys[:api_key].blank?
      errors.add(:base, :api_key_missing)
    end
    true
  end

  def set_unique_hash
    return unless api_key
    self.unique_hash = { api_key: api_key }
  end

  def get( url, params = {} )
    try = params.delete(:try) || 1
    resp = begin
      log "GET #{url}, #{params}"
      RestClient.get( url, params: params )
    rescue Net::ReadTimeout, RestClient::Exceptions::ReadTimeout
      raise TimeoutError.new(
        "Request timed out. You might want to let Mushroom Observer know that #{url} may not be working"
      )
    end
    if resp.code == 429
      log "429 error from Mushroom Observer for #{url}, try #{try}"
      if tries > 3
        raise TooManyRequestsError.new(
          "This process made too many requests to Mushroom Observer so MO stopped returning our calls"
        )
      end
      sleep try * 30 # seconds
      resp = get( url, params.merge( try: try + 1 ) )
    end
    resp
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
          if o && !o.save
            mo_url_from_result( result )
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
    log "Error: #{exception_string}\n#{e.backtrace}"
    update_attributes(
      finished_at: Time.now,
      error: "Error",
      exception: user.is_admin? ? [exception_string, e.backtrace].join("\n") : exception_string
    )
    Emailer.moimport_finished( self, errors, @warnings ).deliver_now
    false
  end

  def log( msg )
    msg = "#{self.class.name} #{id}: #{msg}"
    if options[:logger] == "stdout"
      puts
      puts "[INFO] #{msg}"
      puts
    else
      Rails.logger.info "#{msg}"
    end
  end

  def get_results_xml( options = {} )
    page = options[:page] || 1
    url = "https://mushroomobserver.org/api2/observations.xml"
    return [] if api_key.blank?
    return [] if mo_user_id.blank?
    resp = get( url, {
      user: mo_user_id,
      detail: "high",
      page: page,
      api_key: api_key
    } )
    Nokogiri::XML( resp ).search( "result" )
  rescue RestClient::Forbidden
    raise ForbiddenError.new( "API key does not have permission to retrieve observations" )
  end

  def mo_user_id( for_api_key = nil )
    unless @mo_user_id
      for_api_key ||= api_key
      xml = Nokogiri::XML( get( "https://mushroomobserver.org/api2/api_keys.xml", api_key: for_api_key ) )
      @mo_user_id = xml.at( "response/user" ).try(:[], :id)
    end
    @mo_user_id
  rescue RestClient::Forbidden
    raise ForbiddenError.new( "API key is not valid" )
  end

  def mo_user_name( for_api_key = nil )
    if !@mo_user_name && ( user_id = mo_user_id )
      xml = Nokogiri::XML( get(
        "https://mushroomobserver.org/api2/users.xml",
        id: user_id,
        detail: "high",
        api_key: api_key
      ) )
      @mo_user_name = xml.at( "login_name" ).try(:text)
    end
    @mo_user_name
  rescue RestClient::Forbidden
    raise ForbiddenError.new( "API key does not have permission to retrieve user info" )
  end

  def api_key
    return nil unless inputs && inputs.first && inputs.first.extra
    @api_key ||= inputs.first.extra[:api_key]&.strip
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

  def taxon_for_name( name )
    taxon = Taxon.single_taxon_for_name( name, iconic_taxa: [
      Taxon::ICONIC_TAXA_BY_NAME["Fungi"],
      Taxon::ICONIC_TAXA_BY_NAME["Protozoa"]
    ] )
    taxon ||= Taxon.import( name, ancestor: Taxon::ICONIC_TAXA_BY_NAME["Fungi"] ) rescue nil
    if taxon && taxon.persisted?
      # make sure this isn't a Ratatosk adapter
      return Taxon.find_by_id( taxon.id )
    end
    nil
  end

  def mo_url_from_result( result )
    "http://mushroomobserver.org/observer/show_observation/#{result[:id]}"
  end

  def observation_from_result( result, options = {} )
    mo_url = mo_url_from_result( result )
    # Ensure there's actually response to this URL and it's not an error other
    # than Unauthorized or Forbidden
    unless ( h = fetch_head( mo_url ) ) && ( h.code.to_i < 400 || [401, 403].include?( h.code.to_i ) )
      warn( mo_url, "Mushroom Observer is not showing an observation for this URL" )
      return nil
    end
    log "working on result #{mo_url}"
    if ( is_collection_location = result.at( "is_collection_location" ) ) && is_collection_location[:value] == "false"
      warn( mo_url, "Obs not from collection location, skipped")
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
    o = Observation.new( user: user, geoprivacy: Observation::OPEN )
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
    if ( latitude = result.at( "latitude" ) ) && ( longitude = result.at( "longitude" ) )
      o.latitude = latitude.text.to_f
      o.longitude = longitude.text.to_f
      o.positional_accuracy = nil
      # nesting this here b/c we probably shouldn't set geoprivacy unless viewer
      # has permission to see the true coordinates
      if ( gps_hidden = result.at_css( "> gps_hidden" ) ) && gps_hidden[:value] == "true"
        o.geoprivacy = Observation::PRIVATE
      end
    end
    # This would prioritize the owner's name if we wanted to do that, but after
    # implementing this, I feel like it's probably preferrable to use the
    # consensus name
    # owner_naming = result.search( "> namings / naming" ).detect{|n|
    #   n.at( "owner" ).try(:[], :id) == mo_user_id
    # }&.at( "name" )
    owner_naming = nil
    consensus_naming = result.at( "consensus_name" )
    [owner_naming, consensus_naming].compact.each do |naming|
      begin
        name = naming.at( "name" ).text
        taxon = taxon_for_name( name )
        if o.taxon.blank? && taxon && taxon.persisted?
          o.taxon = taxon
          if taxon.name != name
            warn( mo_url, "Name mismatch, #{name} on MO, #{taxon.name} on iNat" )
          end
        end
        o.species_guess ||= name
      rescue ActiveRecord::AssociationTypeMismatch
        warn( mo_url, "Failed to import a new taxon for #{name}")
      end
    end
    if consensus_naming
      name = consensus_naming.at( "name" ).text
      o.observation_field_values.build( observation_field: mo_name_observation_field, value: [
        name,
        consensus_naming.at( "author" ).try(:text)
      ].compact.join(" ") )
    end
    if owner_naming
      name = owner_naming.at( "name" ).text
      o.observation_field_values.build( observation_field: mo_name_observation_field, value: [
        name,
        owner_naming.at( "author" ).try(:text)
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
    if notes_fields = result.at_css( "> notes_fields" )
      o.description ||= ""
      notes_fields_hash = notes_fields.children.inject( {} ) do |memo, notes_field|
        key = notes_field.at( "key" ).try(:text)
        val = notes_field.at( "value" ).try(:text)
        memo[key] = val if key && val
        memo
      end
      unless notes_fields_hash.blank?
        o.description += "\n\n#{notes_fields_hash.map{|k,v| "<strong>#{k}</strong>: #{v}"}.join( "\n\n" )}"
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
      field_name = "Mushroom Observer Consensus Name"
      @mo_name_observation_field = ObservationField.find_by_name( field_name )
      @mo_name_observation_field ||= ObservationField.create!(
        name: field_name,
        datatype: ObservationField::TEXT,
        description: "Consensus taxon name for this record on https://mushroomobserver.org"
      )
    end
    @mo_name_observation_field
  end

  def mo_owner_name_observation_field
    unless @mo_owner_name_observation_field
      field_name = "Mushroom Observer Owner Name"
      @mo_owner_name_observation_field = ObservationField.find_by_name( field_name )
      @mo_owner_name_observation_field ||= ObservationField.create!(
        name: field_name,
        datatype: ObservationField::TEXT,
        description: "Taxon name applied by the owner of this record on https://mushroomobserver.org"
      )
    end
    @mo_owner_name_observation_field
  end
end
