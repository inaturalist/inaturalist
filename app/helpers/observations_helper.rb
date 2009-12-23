module ObservationsHelper
  def observation_image_url(observation, params = {})
    return nil if observation.photos.empty?
    size = params[:size] ? "#{params[:size]}_url" : 'square_url'
    observation.photos.first.send(size)
  end
  
  def short_observation_description(observation)
    truncate(sanitize(observation.description), :length => 150)
  end
end
