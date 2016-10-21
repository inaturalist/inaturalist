class AddListTaxonIndexToListedTaxon < ActiveRecord::Migration
  def change
    remove_index :listed_taxa, [:list_id, :taxon_id]
    add_index :listed_taxa, [:list_id, :taxon_id], unique: true
  end
end
