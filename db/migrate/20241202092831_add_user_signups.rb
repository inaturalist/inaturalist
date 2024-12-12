class AddUserSignups < ActiveRecord::Migration[6.1]
  def change
    create_table :user_signups do | t |
      t.integer :user_id
      t.string :ip
      t.boolean :vpn
      t.string :browser_id
      t.boolean :incognito
      t.integer :root_user_id_by_ip
      t.integer :root_user_id_by_browser_id
      t.timestamps
    end

    add_index :user_signups, :user_id, unique: true
    add_index :user_signups, :ip
    add_index :user_signups, :browser_id
    add_index :user_signups, [:ip, :browser_id]
  end
end
