class TaxonSweeper < ActionController::Caching::Sweeper
  observe Taxon
  include Shared::SweepersModule
  
  def after_update(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Observation.send_later(:expire_components_for, taxon.id)
    expire_listed_taxa(taxon)
    expire_fragment(:controller => 'taxa', :action => 'photos', :id => taxon.id, :partial => "photo")
    expire_action(:controller => 'taxa', :action => 'show', :id => taxon.id)
    expire_action(:controller => 'taxa', :action => 'show', :id => taxon.to_param)
  end
  
  def after_destroy(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    Observation.of(taxon).find_each {|obs| expire_observation_components(obs)}
    expire_listed_taxa(taxon)
    expire_action(:controller => 'taxa', :action => 'show', :id => taxon.id)
    expire_action(:controller => 'taxa', :action => 'show', :id => taxon.to_param)
  end
end
