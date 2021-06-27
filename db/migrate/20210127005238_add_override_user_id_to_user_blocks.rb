class AddOverrideUserIdToUserBlocks < ActiveRecord::Migration
  def change
    add_column :user_blocks, :override_user_id, :integer, index: true
    add_index :user_blocks, :override_user_id
  end
end
