class CommentSweeper  < ActionController::Caching::Sweeper
  observe Comment, Identification
  include Shared::SweepersModule
  
  def after_save(item)
    sweep_comment(item)
    true
  end
  
  def after_destroy(item)
    sweep_comment(item)
    true
  end
  
  def sweep_comment(item)
    if item.is_a?(Comment)
      expire_listed_taxon(item.parent) if item.parent.is_a?(ListedTaxon)
      expire_observation_components(item.parent) if item.parent.is_a?(Observation)
    else
      expire_observation_components(item.observation)
    end
  end
end
