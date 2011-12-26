class AddClientToObservations < ActiveRecord::Migration
  def self.up
    add_column :observations, :user_agent, :string
    add_column :observations, :positioning_method, :string
    add_column :observations, :positioning_device, :string
  end

  def self.down
    remove_column :observations, :user_agent
    remove_column :observations, :positioning_method
    remove_column :observations, :positioning_device
  end
end
