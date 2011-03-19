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
end
