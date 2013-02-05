class AddKeyToUpdates < ActiveRecord::Migration
  def change
    add_index :updates, [:resource_type, :resource_id, :notifier_type, :notifier_id, :subscriber_id, :notification], 
      :name => :updates_unique_key, :unique => true
  end
end
