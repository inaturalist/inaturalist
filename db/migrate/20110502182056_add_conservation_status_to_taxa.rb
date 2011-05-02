class AddConservationStatusToTaxa < ActiveRecord::Migration
  def self.up
    add_column :taxa, :conservation_status, :integer
    add_column :taxa, :conservation_status_source_id, :integer
    add_index :taxa, :conservation_status_source_id
  end

  def self.down
    remove_column :taxa, :conservation_status
    remove_column :taxa, :conservation_status_source_id
  end
end
