class AddUserToProjectObservation < ActiveRecord::Migration
  def up
    add_column :project_observations, :user_id, :integer
    add_index :project_observations, :user_id
    execute <<-SQL
      UPDATE project_observations SET user_id = observations.user_id 
      FROM observations WHERE observations.id = project_observations.observation_id
    SQL
  end

  def down
    remove_column :project_observations, :user_id
  end
end
