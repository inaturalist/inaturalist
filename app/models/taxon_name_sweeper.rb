class TaxonNameSweeper < ActionController::Caching::Sweeper
  observe TaxonName
  include Shared::SweepersModule
  
  def after_save(taxon_name)
    expire_listed_taxa(taxon_name.taxon_id)
  end
  
  def after_destroy(taxon_name)
    expire_listed_taxa(taxon_name.taxon_id)
  end
end
