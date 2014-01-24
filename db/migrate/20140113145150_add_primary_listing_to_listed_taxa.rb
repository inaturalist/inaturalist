class AddPrimaryListingToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :primary_listing, :boolean

    ListedTaxon.where("place_id IS NOT NULL").find_each do |listed_taxon|
      listed_taxon.make_primary_if_no_primary_exists
    end
  end

  def self.down
    remove_column :listed_taxa, :primary_listing
  end
  
end
