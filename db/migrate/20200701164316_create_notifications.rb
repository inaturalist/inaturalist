class CreateNotifications < ActiveRecord::Migration
  def change
    create_table :notifications do |t|
      t.integer :user_id
      t.string :resource_type
      t.integer :resource_id
      t.boolean :is_resource_owner
      t.string :category
      t.integer :primary_notifier_id
      t.datetime :notifier_date
    end
    add_index :notifications, :user_id

    create_table :notifications_notifiers do |t|
      t.integer :notification_id
      t.integer :notifier_id
      t.string :category
      t.string :reason
      t.datetime :viewed_at
      t.datetime :read_at
    end
    add_index :notifications_notifiers, [:notification_id, :notifier_id, :reason],
      unique: true, name: "index_notifications_notifiers_unique"

    create_table :notifiers do |t|
      t.string :resource_type
      t.integer :resource_id
      t.datetime :action_date
    end
  end
end
