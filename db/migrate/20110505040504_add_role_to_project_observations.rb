class AddRoleToProjectObservations < ActiveRecord::Migration
  def self.up
    add_column :project_observations, :curator_identification_id, :integer
  end

  def self.down
    remove_column :project_observations, :curator_identification_id
  end
end
