module ObservationsHelper
  def observation_image_url(observation, params = {})
    return nil if observation.observation_photos.blank?
    size = params[:size].blank? ? "square" : params[:size]
    first_observation_photo = observation.observation_photos.
     select{ |op| op.photo && !op.photo.hidden? && !op.photo.flagged? }.
     sort_by do |op|
      op.position || observation.observation_photos.size + op.id.to_i
    end.first
    return nil if !first_observation_photo
    url = first_observation_photo.photo.best_url( size )
    return nil if !url
    # this assumes you're not using SSL *and* locally hosted attachments for observations
    if params[:ssl] || ( defined?( request ) && request && request.protocol =~ /https/ )
      url = url.sub("http://", "https://s3.amazonaws.com/")
    end
    url
  end
  
  def short_observation_description(observation)
    truncate(sanitize(observation.description), :length => 150)
  end
  
  def observations_order_by_options(order_by = nil)
    order_by ||= @order_by
    fields = ObservationsController::ORDER_BY_FIELDS - %w(species_guess)
    pairs = fields.map do |f|
      next if f == "project" && @project.blank?
      value = %w(created_at observations.id id).include?(f) ? "observations.id" : f
      default = ObservationsController::DISPLAY_ORDER_BY_FIELDS[f].to_s
      key = default.parameterize.underscore
      key_capitalized = "#{key}_"
      [t( key_capitalized, default: t( key, default: default ) ), value]
    end.compact
    order_by = "observations.id" if order_by.blank?
    options_for_select(pairs, order_by)
  end
  
  def show_observation_coordinates?(observation)
    ![observation.latitude, observation.longitude, 
        observation.private_latitude, observation.private_longitude].compact.blank? &&
        (!observation.geoprivacy_private? || observation.coordinates_viewable_by?(current_user))
  end
  
  def observation_place_guess(observation, options = {})
    display_lat = observation.latitude
    display_lon = observation.longitude
    coordinates_viewable = observation.coordinates_viewable_by?( current_user )
    display_place_guess = coordinates_viewable ? observation.private_place_guess : observation.place_guess
    display_place_guess = observation.place_guess if display_place_guess.blank?
    if !observation.private_latitude.blank? && coordinates_viewable
      display_lat = observation.private_latitude
      display_lon = observation.private_longitude
    end
    
    google_search_link = link_to("Google", "http://maps.google.com/?q=#{observation.place_guess}", :target => "_blank", rel: "noopener noreferrer")
    google_coords_link = link_to("Google", "http://maps.google.com/?q=#{display_lat},#{display_lon}&z=#{observation.map_scale}", :target => "_blank", rel: "noopener noreferrer")
    osm_search_link = link_to("OSM", "http://nominatim.openstreetmap.org/search?q=#{observation.place_guess}", :target => "_blank", rel: "noopener noreferrer")
    osm_coords_url = "http://www.openstreetmap.org/?mlat=#{display_lat}&mlon=#{display_lon}"
    osm_coords_url += "&zoom=#{observation.map_scale}" unless observation.map_scale.blank?
    osm_coords_link = link_to("OSM", osm_coords_url, :target => "_blank", rel: "noopener noreferrer")
    
    if coordinate_truncation = options[:truncate_coordinates]
      coordinate_truncation = 6 unless coordinate_truncation.is_a?(Integer)
      display_lat = display_lat.to_s[0..coordinate_truncation] + "..." unless display_lat.blank?
      display_lon = display_lon.to_s[0..coordinate_truncation] + "..." unless display_lon.blank?
    end
    
    if !display_place_guess.blank? && coordinates_viewable
      place_guess = if observation.lat_lon_in_place_guess? && coordinate_truncation
        "<nobr>#{display_lat},</nobr> <nobr>#{display_lon}</nobr>"
      elsif options[:place_guess_truncation]
        display_place_guess.truncate( options[:place_guess_truncation] )
      else
        display_place_guess
      end
      link_to(place_guess.html_safe, observations_path(:lat => observation.latitude, :lng => observation.longitude)) +
       " (#{google_coords_link}, #{osm_coords_link})".html_safe
    elsif !observation.latitude.blank? && !observation.coordinates_obscured?
      link_to("<nobr>#{display_lat},</nobr> <nobr>#{display_lon}</nobr>".html_safe, 
        observations_path(:lat => observation.latitude, :lng => observation.longitude)) +
        " (#{google_coords_link}, #{osm_coords_link})".html_safe
        
    elsif !observation.private_latitude.blank? && observation.coordinates_viewable_by?(current_user)
      link_to("<nobr>#{display_lat}</nobr>, <nobr>#{display_lon}</nobr>".html_safe, 
        observations_path(:lat => observation.private_latitude, :lng => observation.private_longitude)) +
        " (#{google_coords_link}, #{osm_coords_link})".html_safe
    elsif display_place_guess.blank?
      if observation.geoprivacy == Observation::PRIVATE
        content_tag(:span, t(:private_))
      else
        content_tag(:span, t(:location_unknown))
      end
    elsif !display_lat.blank?
      link_to( display_place_guess.html_safe, observations_path( lat: observation.latitude, lng: observation.longitude ) ) +
        " (#{google_coords_link}, #{osm_coords_link})".html_safe
    elsif observation.geoprivacy == Observation::PRIVATE
      content_tag(:span, t(:private_))
    else
      content_tag(:span, t(:location_unknown))
    end
  end

  def coordinate_system_select_options(options = {})
    return {} unless @site.coordinate_systems
    systems = if options[:skip_lat_lon]
      {}
    else
      { "#{t :latitude} / #{t :longitude} (WGS84, EPSG:4326)" => 'wgs84' }
    end
    @site.coordinate_systems.to_h.each do |system_name, system|
      systems[system["label"]] = options[:names] ? system_name : system["proj4"]
    end
    systems
  end

  def field_value_example(datatype, allowed_values = nil, field_id = nil)
    str = if allowed_values.blank?
      case datatype
      when 'text'
        'alphanumeric string'
      when 'datetime', 'date'
        'YYYY-MM-DD or YYYY-MM-DD HH:MM:SS'
      when 'latitude'
        'dd.dddd (latitude) or ddddddd (northing)'
      when 'longitude'
        'dd.dddd (longitude) or ddddddd (easting)'
      when 'boolean'
        'yes or no'
      when 'list'
        'limited set of options, usually alphanumeric'
      when 'number'
      when 'numeric'
        'positive whole number'
      else
        nil
      end
    else
      "One of #{allowed_values.split('|').to_sentence(:two_words_connector => ' or ', :last_word_connector => ' or ')}"
    end

    unless field_id.nil?
      proj_obs_field = ProjectObservationField.find_by_observation_field_id(field_id)
      str = "#{str}, #{content_tag('strong', 'required')}".html_safe if proj_obs_field.required
    end

    str
  end

end
