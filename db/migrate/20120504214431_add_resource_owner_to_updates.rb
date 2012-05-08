class AddResourceOwnerToUpdates < ActiveRecord::Migration
  def self.up
    add_column :updates, :resource_owner_id, :integer
    add_column :updates, :viewed_at, :timestamp
    add_index :updates, :resource_owner_id
    add_index :updates, :viewed_at
  end

  def self.down
    remove_column :updates, :resource_owner_id
    remove_column :updates, :viewed_at
  end
end
