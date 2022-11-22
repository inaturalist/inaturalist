class TaxonNameSweeper < ActionController::Caching::Sweeper
  begin
    observe TaxonName
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to observe TaxonName. Ignore if setting up for the first time"
  end
  include Shared::SweepersModule
  
  def after_save(taxon_name)
    expire_listed_taxa(taxon_name.taxon_id)
  end
  
  def after_destroy(taxon_name)
    expire_listed_taxa(taxon_name.taxon_id)
  end
end
