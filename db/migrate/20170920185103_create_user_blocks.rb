class CreateUserBlocks < ActiveRecord::Migration
  def change
    create_table :user_blocks do |t|
      t.integer :user_id
      t.integer :blocked_user_id

      t.timestamps null: false
    end
    add_index :user_blocks, :user_id
    add_index :user_blocks, :blocked_user_id
  end
end
