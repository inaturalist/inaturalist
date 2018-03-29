class AddIndexToPreferencesAndProjectUsersUpdatedAt < ActiveRecord::Migration
  def change
    add_index :preferences, :updated_at
    add_index :project_users, :updated_at
  end
end
