class AddOutOfRangeToObservations < ActiveRecord::Migration
  def self.up
    add_column :observations, :out_of_range, :boolean
    add_index :observations, :out_of_range
  end

  def self.down
    remove_column :observations, :out_of_range
  end
end
