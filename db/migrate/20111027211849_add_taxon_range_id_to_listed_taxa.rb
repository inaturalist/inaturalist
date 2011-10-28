class AddTaxonRangeIdToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :taxon_range_id, :integer
    add_column :listed_taxa, :source_id, :integer
    add_index :listed_taxa, :taxon_range_id
    add_index :listed_taxa, :source_id
  end

  def self.down
    remove_column :listed_taxa, :taxon_range_id
    remove_column :listed_taxa, :source_id
  end
end
