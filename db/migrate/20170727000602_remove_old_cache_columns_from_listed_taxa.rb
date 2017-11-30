class RemoveOldCacheColumnsFromListedTaxa < ActiveRecord::Migration
  def self.up
    remove_column :listed_taxa, :observations_month_counts
    remove_column :listed_taxa, :taxon_ancestor_ids
  end

  def self.down
    add_column :listed_taxa, :observations_month_counts, :string
    add_column :listed_taxa, :taxon_ancestor_ids, :string
  end
end
