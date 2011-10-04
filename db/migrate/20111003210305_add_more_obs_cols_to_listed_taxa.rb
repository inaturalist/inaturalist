class AddMoreObsColsToListedTaxa < ActiveRecord::Migration
  def self.up
    add_column :listed_taxa, :first_observation_id, :integer
    add_index :listed_taxa, :first_observation_id
    
    add_column :listed_taxa, :observations_count, :integer, :default => 0
    add_index :listed_taxa, [:place_id, :observations_count]
    
    add_column :listed_taxa, :observations_month_counts, :string
  end

  def self.down
    remove_column :listed_taxa, :first_observation_id
    remove_column :listed_taxa, :observations_count
    remove_column :listed_taxa, :observations_month_counts
  end
end
