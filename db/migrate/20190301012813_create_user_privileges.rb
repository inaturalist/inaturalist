class CreateUserPrivileges < ActiveRecord::Migration
  def change
    create_table :user_privileges do |t|
      t.integer :user_id
      t.string :privilege
      t.timestamp :revoked_at
      t.integer :revoke_user_id
      t.string :revoke_reason
      t.timestamps
    end
    add_index :user_privileges, :user_id
    add_index :user_privileges, :revoke_user_id
  end
end
