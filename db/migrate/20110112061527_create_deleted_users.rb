class CreateDeletedUsers < ActiveRecord::Migration
  def self.up
    create_table :deleted_users do |t|
      t.integer :user_id
      t.string :login
      t.string :email
      t.timestamp :user_created_at
      t.timestamp :user_updated_at
      t.integer :observations_count

      t.timestamps
    end
    
    add_index :deleted_users, :user_id
    add_index :deleted_users, :login
  end

  def self.down
    drop_table :deleted_users
  end
end
