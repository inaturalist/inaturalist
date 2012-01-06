class AddManuallyAddedToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :manually_added, :boolean, :default => false
  end

  def self.down
    remove_column :listed_taxa, :manually_added
  end
end
