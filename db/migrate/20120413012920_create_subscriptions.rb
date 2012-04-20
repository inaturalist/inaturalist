class CreateSubscriptions < ActiveRecord::Migration
  def self.up
    create_table :subscriptions do |t|
      t.integer :user_id
      t.string :resource_type
      t.integer :resource_id
    
      t.timestamps
    end
    
    add_index :subscriptions, :user_id
    add_index :subscriptions, [:resource_type, :resource_id]
  end

  def self.down
    drop_table :subscriptions
  end
end
