class AddIndexesToTaxonChanges < ActiveRecord::Migration
  def self.up
    add_index :taxon_changes, :user_id
    add_index :taxon_changes, :source_id
    add_index :taxon_changes, :taxon_id
    add_index :taxon_change_taxa, :taxon_id
    add_index :taxon_change_taxa, :taxon_change_id
    add_index :taxon_schemes, :source_id
    add_index :taxon_scheme_taxa, :taxon_id
    add_index :taxon_scheme_taxa, :taxon_scheme_id
  end

  def self.down
    remove_index :taxon_changes, :user_id
    remove_index :taxon_changes, :source_id
    remove_index :taxon_changes, :taxon_id
    remove_index :taxon_change_taxa, :taxon_id
    remove_index :taxon_change_taxa, :taxon_change_id
    remove_index :taxon_scheme_taxa, :taxon_id
    remove_index :taxon_scheme_taxa, :taxon_scheme_id
  end
end
