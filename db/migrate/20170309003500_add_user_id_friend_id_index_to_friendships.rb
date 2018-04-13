class AddUserIdFriendIdIndexToFriendships < ActiveRecord::Migration
  def change
    add_index :friendships, [:user_id, :friend_id], unique: true
  end
end
