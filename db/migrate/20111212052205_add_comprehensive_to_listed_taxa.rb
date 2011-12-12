class AddComprehensiveToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :comprehensive, :boolean, :default => false
  end

  def self.down
    remove_column :listed_taxa, :comprehensive, :boolean
  end
end
