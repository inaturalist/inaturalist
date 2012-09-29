class AdjustUpdatesIndexes < ActiveRecord::Migration
  def up
    remove_index :updates, :viewed_at
    remove_index :updates, :subscriber_id
    add_index :updates, [:subscriber_id, :viewed_at, :notification]
  end

  def down
    remove_index :updates, [:subscriber_id, :viewed_at, :notification]
    add_index :updates, :viewed_at
    add_index :updates, :subscriber_id
  end
end
