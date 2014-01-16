class AddPrimaryListingToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :primary_listing, :boolean, :default => true
  end

  def self.down
    remove_column :listed_taxa, :primary_listing
  end
  
end
