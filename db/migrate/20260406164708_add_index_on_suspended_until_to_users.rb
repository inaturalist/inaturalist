class AddIndexOnSuspendedUntilToUsers < ActiveRecord::Migration[6.1]
  def change
    add_index :users, :suspended_until
  end
end
