class TaxonSweeper < ActionController::Caching::Sweeper
  observe Taxon
  include Shared::SweepersModule
  
  def after_save(taxon)
    Observation.of(taxon).each {|obs| expire_observation_components(obs)}
    expire_listed_taxa(taxon)
    expire_fragment(:controller => 'taxa', :action => 'photos', :id => taxon.id, :partial => "photo")
  end
  
  def after_destroy(taxon)
    Observation.of(taxon).each {|obs| expire_observation_components(obs)}
    expire_listed_taxa(taxon)
  end
end
