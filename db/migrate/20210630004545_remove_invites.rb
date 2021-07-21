class RemoveInvites < ActiveRecord::Migration
  def up
    drop_table :invites
  end
  def down
    create_table :invites do |t|
      t.integer :user_id
      t.string :invite_address
      t.timestamps
    end
  end
end
