module ObservationsHelper
  def observation_image_url(observation, params = {})
    return nil if observation.observation_photos.blank?
    size = params[:size] ? "#{params[:size]}_url" : 'square_url'
    photo = observation.observation_photos.sort_by do |op|
      op.position || observation.observation_photos.size + op.id.to_i
    end.first.photo
    url = photo.send(size)
    # this assumes you're not using SSL *and* locally hosted attachments for observations
    if request && request.protocol =~ /https/
      url.sub("http://", "https://s3.amazonaws.com/")
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
      value = %w(created_at observations.id id).include?(f) ? 'observations.id' : f
      default = ObservationsController::DISPLAY_ORDER_BY_FIELDS[f].to_s
      key = default.parameterize.underscore
      [t(key, :default => default).downcase, value]
    end.compact
    order_by = 'observations.id' if order_by.blank?
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
    coordinates_viewable = observation.coordinates_viewable_by?(current_user)
    if !observation.private_latitude.blank? && coordinates_viewable
      display_lat = observation.private_latitude
      display_lon = observation.private_longitude
    end
    
    google_search_link = link_to("Google", "http://maps.google.com/?q=#{observation.place_guess}", :target => "_blank")
    google_coords_link = link_to("Google", "http://maps.google.com/?q=#{display_lat},#{display_lon}&z=#{observation.map_scale}", :target => "_blank")
    osm_search_link = link_to("OSM", "http://nominatim.openstreetmap.org/search?q=#{observation.place_guess}", :target => "_blank")
    osm_coords_url = "http://www.openstreetmap.org/?mlat=#{display_lat}&mlon=#{display_lon}"
    osm_coords_url += "&zoom=#{observation.map_scale}" unless observation.map_scale.blank?
    osm_coords_link = link_to("OSM", osm_coords_url, :target => "_blank")
    
    if coordinate_truncation = options[:truncate_coordinates]
      coordinate_truncation = 6 unless coordinate_truncation.is_a?(Fixnum)
      display_lat = display_lat.to_s[0..coordinate_truncation] + "..." unless display_lat.blank?
      display_lon = display_lon.to_s[0..coordinate_truncation] + "..." unless display_lon.blank?
    end
    
    if !observation.place_guess.blank? && coordinates_viewable
      place_guess = if observation.lat_lon_in_place_guess? && coordinate_truncation
        "<nobr>#{display_lat},</nobr> <nobr>#{display_lon}</nobr>"
      elsif options[:place_guess_truncation]
        observation.place_guess.truncate(options[:place_guess_truncation])
      else
        observation.place_guess
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
    else
      content_tag(:span, t(:somewhere))
    end
  end

  def title_for_observation_params(options = {})
    s = options[:lead] || t(:observation_stats, :default => "Observation stats")
    s += " #{t :of} #{link_to_taxon @observations_taxon}" if @observations_taxon
    if @rank
      s += " #{t :of} #{t "ranks.#{@rank}"}"
    elsif @hrank
      s += " #{t :of} #{t "ranks.#{@hrank}"} #{t :or_lower, :default => "or lower"}"
    elsif @lrank
      s += " #{t :of} #{t "ranks.#{@lrank}"} #{t :or_higher, :default => "or higher"}"
    end
    s += " #{t(:from).downcase} #{link_to @place.display_name, @place}" if @place
    s += " #{t :by} #{link_to @user.login, @user}" if @user
    if @observed_on
      s += " #{@observed_on_day ? t(:on).downcase : t(:in).downcase} #{@observed_on}"
    elsif @d1 && @d2
      s += " #{t(:between).downcase} #{@d1} #{t :and} #{@d2}"
    end
    if @projects
      s += " #{ t(:in, default: "in").downcase} #{commas_and(@projects.map{|p| link_to(p.title, p)})}"
    end
    s.html_safe
  end
  
  def coordinate_system_select_options(options = {})
    return {} unless CONFIG.coordinate_systems
    systems = if options[:skip_lat_lon]
      {}
    else
      { "#{t :latitude} / #{t :longitude} (WGS84, EPSG:4326)" => 'wgs84' }
    end
    CONFIG.coordinate_systems.to_h.each do |system_name, system|
      systems[system[:label]] = options[:names] ? system_name : system.proj4
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
