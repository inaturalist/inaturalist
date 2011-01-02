class ObservationSweeper < ActionController::Caching::Sweeper  
  observe Observation
  include Shared::SweepersModule
  
  def after_update(observation)
    expire_observation_components(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    true
  end
  
  def after_destroy(observation)
    expire_observation_components(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    true
  end 
end
