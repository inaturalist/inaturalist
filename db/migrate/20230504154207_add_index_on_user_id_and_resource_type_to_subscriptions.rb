class AddIndexOnUserIdAndResourceTypeToSubscriptions < ActiveRecord::Migration[6.1]
  def change
    add_index :subscriptions, [:user_id, :resource_type]
  end
end
