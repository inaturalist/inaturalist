class ObservationSweeper < ActionController::Caching::Sweeper  
  observe Observation
  include Shared::SweepersModule
  
  def after_create(observation)
    expire_taxon_caches_for_observation(observation)
    expire_page observations_by_login_all_path(observation.user.login, :format => 'csv')
    true
  end
  
  def after_update(observation)
    expire_observation_components(observation)
    expire_taxon_caches_for_observation(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    expire_page observations_by_login_all_path(observation.user.login, :format => 'csv')
    true
  end
  
  def after_destroy(observation)
    expire_observation_components(observation)
    expire_taxon_caches_for_observation(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    expire_page observations_by_login_all_path(observation.user.login, :format => 'csv')
    true
  end 
  
  def expire_taxon_caches_for_observation(observation)
    return unless (observation.taxon_id_changed? || observation.latitude_changed?)
    
    if observation.taxon_id_was && (taxon_was = Taxon.find_by_id(observation.taxon_id_was))
      expire_taxon_caches_for_taxon(taxon_was)
    end
    
    if observation.taxon_id && (taxon_is = Taxon.find_by_id(observation.taxon_id))
      expire_taxon_caches_for_taxon(taxon_is)
    end
  end
  
  def expire_taxon_caches_for_taxon(t)
    expire_action(:controller => 'taxa', :action => 'show', :id => t.to_param)
    expire_action(:controller => 'taxa', :action => 'show', :id => t.id)
    expire_action(:controller => 'observations', :action => 'of', :id => t.id, :format => "json")
    expire_action(:controller => 'observations', :action => 'of', :id => t.id, :format => "geojson")
  end
end
