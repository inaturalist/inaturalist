class RemoveParentIdFromTaxa < ActiveRecord::Migration
  def up
    remove_column :taxa, :parent_id
  end

  def down
    add_column :taxa, :parent_id, :integer
    add_index :taxa, :parent_id
  end
end
