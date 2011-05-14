class AddPrivateGeoFieldsToObservations < ActiveRecord::Migration
  def self.up
    add_column :observations, :private_latitude, :decimal, :precision => 15, :scale => 10
    add_column :observations, :private_longitude, :decimal, :precision => 15, :scale => 10
    add_column :observations, :private_positional_accuracy, :integer
  end

  def self.down
    remove_column :observations, :private_latitude, :decimal
    remove_column :observations, :private_longitude, :decimal
    remove_column :observations, :private_positional_accuracy
  end
end
