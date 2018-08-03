class AddSuspendedByUserIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :suspended_by_user_id, :integer
  end
end
