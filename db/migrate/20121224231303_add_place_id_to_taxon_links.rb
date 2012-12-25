class AddPlaceIdToTaxonLinks < ActiveRecord::Migration
  def change
    add_column :taxon_links, :place_id, :integer
    add_column :taxon_links, :species_only, :boolean, :default => false
    add_index :taxon_links, :place_id
  end
end
