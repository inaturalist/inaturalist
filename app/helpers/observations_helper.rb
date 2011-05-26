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
    pairs = ObservationsController::ORDER_BY_FIELDS.map do |f|
      value = %w(created_at observations.id id).include?(f) ? 'observations.id' : f
      [ObservationsController::DISPLAY_ORDER_BY_FIELDS[f], value]
    end
    order_by = 'observations.id' if order_by.blank?
    options_for_select(pairs, order_by)
  end
  
  def observation_place_guess(observation)
    if !observation.place_guess.blank?
      if observation.latitude.blank?
        observation.place_guess + 
        " (#{link_to "Google", "http://maps.google.com/?q=#{observation.place_guess}", :target => "_blank"})".html_safe
      else
        link_to(observation.place_guess, observations_path(:lat => observation.latitude, :lng => observation.longitude)) +
         " (#{link_to("Google", "http://maps.google.com/?q=#{observation.latitude}, #{observation.longitude}", :target => "_blank")})".html_safe
      end
    elsif !observation.latitude.blank? && !observation.coordinates_obscured?
      link_to("#{observation.latitude}, #{observation.longitude}", 
        observations_path(:lat => observation.latitude, :lng => observation.longitude)) +
        " (#{link_to "Google", "http://maps.google.com/?q=#{observation.latitude}, #{observation.longitude}", :target => "_blank"})".html_safe
    else
      content_tag(:span, "(Somewhere...)")
    end
  end
end
