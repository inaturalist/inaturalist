class AddTrackingCodeToProjectObservations < ActiveRecord::Migration
  def self.up
    add_column :project_observations, :tracking_code, :string
    add_column :projects, :tracking_codes, :string
  end

  def self.down
    remove_column :project_observations, :tracking_code, :string
    remove_column :projects, :tracking_codes, :string
  end
end
