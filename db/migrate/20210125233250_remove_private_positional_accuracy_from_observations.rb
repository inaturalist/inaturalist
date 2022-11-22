class RemovePrivatePositionalAccuracyFromObservations < ActiveRecord::Migration
  def self.up
    remove_column :observations, :private_positional_accuracy
  end

  def self.down
    add_column :observations, :private_positional_accuracy, :integer
  end
end
