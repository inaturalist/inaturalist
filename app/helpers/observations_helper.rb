module ObservationsHelper
  def observation_image_url(observation, params = {})
    return nil if observation.observation_photos.blank?
    size = params[:size] ? "#{params[:size]}_url" : 'square_url'
    photo = observation.observation_photos.sort_by do |op|
      op.position || observation.observation_photos.size + op.id.to_i
    end.first.photo
    photo.send(size)
  end
  
  def short_observation_description(observation)
    truncate(sanitize(observation.description), :length => 150)
  end
  
  def observations_order_by_options(order_by = nil)
    order_by ||= @order_by
    pairs = ObservationsController::ORDER_BY_FIELDS.map do |f|
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
    if !observation.private_latitude.blank? && observation.coordinates_viewable_by?(current_user)
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
    
    if !observation.place_guess.blank?
      if observation.latitude.blank?
        "#{observation.place_guess} (#{google_search_link}, #{osm_search_link})".html_safe
      else
        place_guess = if observation.lat_lon_in_place_guess? && coordinate_truncation
          "<nobr>#{display_lat},</nobr> <nobr>#{display_lon}</nobr>"
        else
          observation.place_guess
        end
        link_to(place_guess.html_safe, observations_path(:lat => observation.latitude, :lng => observation.longitude)) +
         " (#{google_coords_link}, #{osm_coords_link})".html_safe
      end
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

  def title_for_observation_params
    s = t(:observed_taxa, :default => "Observed taxa")
    s += " #{t :of} #{link_to_taxon @observations_taxon}" if @observations_taxon
    s += " #{t(:from).downcase} #{link_to @place.display_name, @place}" if @place
    s += " #{t :by} #{link_to @user.login, @user}" if @user
    if @observed_on
      s += " #{@observed_on_day ? t(:on).downcase : t(:in).downcase} #{@observed_on}"
    elsif @d1 && @d2
      s += " #{t(:between).downcase} #{@d1} #{t :and} #{@d2}"
    end
    s.html_safe
  end
  
end
