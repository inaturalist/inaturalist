class AddUserToProjectObservation < ActiveRecord::Migration
  def change
    add_column :project_observations, :user_id, :integer
    add_index :project_observations, :user_id
  end
end
