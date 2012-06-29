class AddCommitDateToTaxonChange < ActiveRecord::Migration
  def self.up
    add_column :taxon_changes, :committed_on, :date
  end

  def self.down
    remove_column :taxon_changes, :committed_on
  end
end
