class RemoveComprehensiveFromListedTaxa < ActiveRecord::Migration
  def self.up
    remove_column :listed_taxa, :comprehensive, :boolean
  end

  def self.down
    add_column :listed_taxa, :comprehensive, :boolean, :default => false
  end
end
