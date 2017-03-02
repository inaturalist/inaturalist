class AddIndexToSubscriptionsUserIdAndResourceType < ActiveRecord::Migration
  def change
    add_index :subscriptions, [ :user_id, :resource_type ]
  end
end
