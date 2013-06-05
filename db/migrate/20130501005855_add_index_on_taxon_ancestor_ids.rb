class AddIndexOnTaxonAncestorIds < ActiveRecord::Migration
  def up
    add_index :listed_taxa, :taxon_ancestor_ids
  end

  def down
    remove_index :listed_taxa, :taxon_ancestor_ids
  end
end
