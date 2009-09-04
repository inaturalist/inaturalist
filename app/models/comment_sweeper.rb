class CommentSweeper  < ActionController::Caching::Sweeper
  observe Comment, Identification
  include Shared::SweepersModule
  
  def after_save(item)
    obs = item.is_a?(Comment) ? item.parent : item.observation
    expire_observation_components(obs) if obs.is_a?(Observation)
  end
  
  def after_destroy(item)
    obs = item.is_a?(Comment) ? item.parent : item.observation
    expire_observation_components(obs) if obs.is_a?(Observation)
  end
end