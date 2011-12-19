class ObservationSweeper < ActionController::Caching::Sweeper  
  observe Observation
  include Shared::SweepersModule
  
  def after_create(observation)
    expire_taxa_show_for_observation(observation)
    true
  end
  
  def after_update(observation)
    expire_observation_components(observation)
    expire_taxa_show_for_observation(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    true
  end
  
  def after_destroy(observation)
    expire_observation_components(observation)
    expire_taxa_show_for_observation(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    true
  end 
  
  def expire_taxa_show_for_observation(observation)
    if observation.taxon_id_was  && (taxon = taxon_was = Taxon.find_by_id(observation.taxon_id_was))
      expire_action(:controller => 'taxa', :action => 'show', :id => taxon_was.to_param)
      expire_action(:controller => 'taxa', :action => 'show', :id => taxon_was.id)
    end
    if observation.taxon_id_changed? && observation.taxon
      expire_action(:controller => 'taxa', :action => 'show', :id => observation.taxon.to_param)
      expire_action(:controller => 'taxa', :action => 'show', :id => observation.taxon.id)
    end
  end
end
