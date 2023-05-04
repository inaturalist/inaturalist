class ModifyCommentsIndices < ActiveRecord::Migration[6.1]
  def change
    remove_index :comments, [:parent_type, :parent_id]
    add_index :comments, [:parent_id, :parent_type]
    add_index :comments, [:parent_type]
  end
end
