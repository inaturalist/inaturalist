class DropUpdatesIndices < ActiveRecord::Migration
  def up
    remove_index :updates, :resource_owner_id
    remove_index :updates, [ :resource_type, :resource_id ]
  end

  def down
    add_index :updates, :resource_owner_id
    add_index :updates, [ :resource_type, :resource_id ]
  end
end
