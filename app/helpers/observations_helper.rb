module ObservationsHelper
  def observation_image_url(observation, params = {})
    return nil if observation.photos.empty?
    size = params[:size] ? "#{params[:size]}_url" : 'square_url'
    observation.photos.first.send(size)
  end
  
  def short_observation_description(observation)
    truncate(sanitize(observation.description), :length => 150)
  end
  
  def observations_order_by_options(order_by = nil)
    order_by ||= @order_by
    pairs = ObservationsController::ORDER_BY_FIELDS.map do |f|
      value = %w(created_at observations.id id).include?(f) ? 'observations.id' : f
      [ObservationsController::DISPLAY_ORDER_BY_FIELDS[f], value]
    end
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
    if coordinate_truncation = options[:truncate_coordinates]
      coordinate_truncation = 6 unless coordinate_truncation.is_a?(Fixnum)
      display_lat = display_lat.to_s[0..coordinate_truncation] + "..." unless display_lat.blank?
      display_lon = display_lon.to_s[0..coordinate_truncation] + "..." unless display_lon.blank?
    end
    
    if !observation.place_guess.blank?
      if observation.latitude.blank?
        observation.place_guess + 
        " (#{link_to "Google", "http://maps.google.com/?q=#{observation.place_guess}", :target => "_blank"})".html_safe
      else
        link_to(observation.place_guess, observations_path(:lat => observation.latitude, :lng => observation.longitude)) +
         " (#{link_to("Google", "http://maps.google.com/?q=#{observation.latitude}, #{observation.longitude}", :target => "_blank")})".html_safe
      end
    elsif !observation.latitude.blank? && !observation.coordinates_obscured?
      link_to("<nobr>#{display_lat},</nobr> <nobr>#{display_lon}</nobr>", 
        observations_path(:lat => observation.latitude, :lng => observation.longitude)) +
        " (#{link_to "Google", "http://maps.google.com/?q=#{observation.latitude}, #{observation.longitude}", :target => "_blank"})".html_safe
        
    elsif !observation.private_latitude.blank? && observation.coordinates_viewable_by?(current_user)
      link_to("<nobr>#{observation.private_latitude}</nobr>, <nobr>#{observation.private_longitude}</nobr>", 
        observations_path(:lat => observation.private_latitude, :lng => observation.private_longitude)) +
        " (#{link_to "Google", "http://maps.google.com/?q=#{observation.private_latitude}, #{observation.private_longitude}", :target => "_blank"})".html_safe
    else
      content_tag(:span, "(Somewhere...)")
    end
  end
  
end
