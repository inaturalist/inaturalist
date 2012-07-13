class ChangeTaxonChangeGroup < ActiveRecord::Migration
  def self.up
    rename_column :taxon_changes, :group, :change_group
  end

  def self.down
    rename_column :taxon_changes, :change_group, :group
  end
end
