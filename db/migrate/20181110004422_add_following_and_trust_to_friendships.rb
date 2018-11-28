class AddFollowingAndTrustToFriendships < ActiveRecord::Migration
  def change
    add_column :friendships, :following, :boolean, default: true
    add_index :friendships, :following
    add_column :friendships, :trust, :boolean, default: false
    add_index :friendships, :trust
  end
end
