class CreateNewUpdatesTables < ActiveRecord::Migration
  def change
    create_table :update_actions do |t|
      t.integer :resource_id
      t.string :resource_type
      t.string :notifier_type
      t.integer :notifier_id
      t.integer :notification
      t.integer :resource_owner_id
      t.datetime :created_at
    end
    # add_index :update_actions,
    #   [ :resource_id, :notifier_id, :resource_type, :notifier_type, :notification ],
    #   unique: true, name: "index_update_actions_unique"
    # add_index :update_actions, :created_at

    create_table :update_subscribers do |t|
      t.integer :update_action_id
      t.string :subscriber_id
      t.datetime :viewed_at
    end
    # add_index :update_subscribers, :update_action_id
    # add_index :update_subscribers, :subscriber_id
  end
end
