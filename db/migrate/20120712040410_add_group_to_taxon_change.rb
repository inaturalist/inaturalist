class AddGroupToTaxonChange < ActiveRecord::Migration
  def self.up
    add_column :taxon_changes, :group, :string
  end

  def self.down
    remove_column :taxon_changes, :group
  end
end
