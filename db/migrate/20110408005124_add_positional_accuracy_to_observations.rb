class AddPositionalAccuracyToObservations < ActiveRecord::Migration
  def self.up
    add_column :observations, :positional_accuracy, :integer
  end

  def self.down
    remove_column :observations, :positional_accuracy
  end
end
