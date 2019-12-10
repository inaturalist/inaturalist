class AddIndexToUsersLastIp < ActiveRecord::Migration
  def change
    add_index :users, :last_ip
  end
end
