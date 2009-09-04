class ObservationSweeper < ActionController::Caching::Sweeper  
  observe Observation
  include Shared::SweepersModule
  
  def after_save(observation)
    expire_observation_components(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
  end
  
  def after_destroy(observation)
    expire_observation_components(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
  end 
end
