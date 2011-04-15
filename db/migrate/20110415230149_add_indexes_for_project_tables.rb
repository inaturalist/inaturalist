class AddIndexesForProjectTables < ActiveRecord::Migration
  def self.up
    add_index :projects, :user_id
    add_index :project_users, :user_id
    add_index :project_users, [:project_id, :taxa_count]
    add_index :project_observations, :observation_id
    add_index :project_observations, :project_id
  end

  def self.down
    remove_index :projects, :user_id
    remove_index :project_users, :user_id
    remove_index :project_users, [:project_id, :taxa_count]
    remove_index :project_observations, :observation_id
    remove_index :project_observations, :project_id
  end
end
