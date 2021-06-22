class AddObservationRequirementsUpdatedAtToProjects < ActiveRecord::Migration
  def up
    add_column :projects, :observation_requirements_updated_at, :timestamp
  end

  def down
    remove_column :projects, :observation_requirements_updated_at
  end
end
