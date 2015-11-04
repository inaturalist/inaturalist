class AddDateFieldsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :last_active, :date
    add_column :users, :subscriptions_suspended_at, :timestamp
  end
end
