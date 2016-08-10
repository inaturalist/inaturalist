class DropUpdatesTable < ActiveRecord::Migration
  def up
    drop_table :updates
  end

  def down
    # not really reversible since all the data will be destroyed,
    # but this will at least restore the table structure
    create_table :updates do |t|
      t.integer :subscriber_id
      t.integer :resource_id
      t.string :resource_type
      t.string :notifier_type
      t.integer :notifier_id
      t.string :notification
      t.timestamps
      t.integer :resource_owner_id
      t.timestamp :viewed_at
    end
  end
end
