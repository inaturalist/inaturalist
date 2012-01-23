class RenameSpeciesCount < ActiveRecord::Migration
  def self.up
    rename_column :projects, :species_count, :observed_taxa_count
  end

  def self.down
    rename_column :projects, :observed_taxa_count, :species_count
  end
end
