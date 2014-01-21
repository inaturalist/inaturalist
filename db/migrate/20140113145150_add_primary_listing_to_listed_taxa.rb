class AddPrimaryListingToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :primary_listing, :boolean, :default => true
    
    ListedTaxon.find_by_sql("SELECT place_id, taxon_id, Count(*) FROM listed_taxa GROUP BY place_id, taxon_id HAVING Count(*) > 1").each do |lt|
      unless lt.place_id.nil?
        listed_taxon = ListedTaxon.where(:taxon_id => lt.taxon_id, :place_id => lt.place_id).first
        listed_taxon.remove_other_primary_listings
      end
    end
  end

  def self.down
    remove_column :listed_taxa, :primary_listing
  end
  
end
