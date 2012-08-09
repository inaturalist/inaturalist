class AddAncestryToPlaces < ActiveRecord::Migration
  def up
    add_column :places, :ancestry, :string
    add_index :places, :ancestry
    Place.build_ancestry_from_parent_ids!
  end

  def down
    remove_column :places, :ancestry
  end
end
