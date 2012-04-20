class CreateUpdates < ActiveRecord::Migration
  def self.up
    create_table :updates do |t|
      t.integer :subscriber_id
      t.integer :resource_id
      t.string :resource_type
      t.string :notifier_type
      t.integer :notifier_id
      t.string :notification
    
      t.timestamps
    end
    add_index :updates, :subscriber_id
    add_index :updates, [:resource_type, :resource_id]
    add_index :updates, [:notifier_type, :notifier_id]
  end

  def self.down
    drop_table :updates
  end
end
