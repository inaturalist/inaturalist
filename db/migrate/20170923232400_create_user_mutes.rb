class CreateUserMutes < ActiveRecord::Migration
  def change
    create_table :user_mutes do |t|
      t.integer :user_id
      t.integer :muted_user_id

      t.timestamps null: false
    end
    add_index :user_mutes, :user_id
    add_index :user_mutes, :muted_user_id
  end
end
