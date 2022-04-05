class TaxonSweeper < ActionController::Caching::Sweeper
  begin
    observe Taxon
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to observe Taxon. Ignore if setting up for the first time"
  end
  include Shared::SweepersModule
  
  def after_update(taxon)
    expire_taxon( taxon )
  end
  
  def after_destroy(taxon)
    taxon = Taxon.find_by_id(taxon) unless taxon.is_a?(Taxon)
    return unless taxon
    expire_listed_taxa(taxon)
  end
end
