class TaxonSweeper < ActionController::Caching::Sweeper
  observe Taxon
  include Shared::SweepersModule
  
  def after_update(taxon)
    TaxonSweeper.send_later(:after_update, taxon.id)
    true
  end
  
  def after_destroy(taxon)
    TaxonSweeper.send_later(:after_destroy, taxon.id)
    true
  end
  
  def self.after_update(taxon)
    return unless (taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon))
    Observation.of(taxon).find_each {|obs| expire_observation_components(obs)}
    expire_listed_taxa(taxon)
    expire_fragment(:controller => 'taxa', :action => 'photos', :id => taxon.id, :partial => "photo")
  end
  
  def self.after_destroy(taxon)
    return unless (taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon))
    Observation.of(taxon).find_each {|obs| expire_observation_components(obs)}
    expire_listed_taxa(taxon)
  end
end
