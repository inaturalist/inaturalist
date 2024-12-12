class AddBlockedIps < ActiveRecord::Migration[6.1]
  def change
    create_table :blocked_ips do | t |
      t.string :ip
      t.integer :user_id
      t.timestamps
    end

    add_index :blocked_ips, :ip, unique: true
  end
end
