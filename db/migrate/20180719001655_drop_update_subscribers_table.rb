class DropUpdateSubscribersTable < ActiveRecord::Migration
  def up
    drop_table :update_subscribers
  end

  def down
    # not really reversible since all the data will be destroyed,
    # but this will at least restore the table structure
    create_table :update_subscribers, id: false do |t|
      t.integer :update_action_id
      t.integer :subscriber_id
      t.datetime :viewed_at
    end
    add_index :update_subscribers, :update_action_id
  end
end
