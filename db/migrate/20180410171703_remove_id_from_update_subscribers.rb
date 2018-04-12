class RemoveIdFromUpdateSubscribers < ActiveRecord::Migration
  def up
    remove_column :update_subscribers, :id
  end

  def down
    add_column :update_subscribers, :id, :primary_key
  end
end
