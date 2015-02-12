class ListedTaxonSweeper < ActionController::Caching::Sweeper
  observe ListedTaxon
  include Shared::SweepersModule
  
  def after_save(listed_taxon)
    expire_listed_taxon(listed_taxon)
    true
  end
  
  def after_destroy(listed_taxon)
    expire_listed_taxon(listed_taxon)
    true
  end
end
