class AddObservationRequirementsUpdatedAtToProjects < ActiveRecord::Migration
  def up
    add_column :projects, :observation_requirements_updated_at, :timestamp
    execute <<-SQL
      UPDATE projects SET observation_requirements_updated_at = updated_at
      WHERE project_type IN ('collection', 'umbrella')
    SQL
  end

  def down
    remove_column :projects, :observation_requirements_updated_at
  end
end
