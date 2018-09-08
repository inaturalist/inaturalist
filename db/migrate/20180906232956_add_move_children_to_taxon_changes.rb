class AddMoveChildrenToTaxonChanges < ActiveRecord::Migration
  def up
    add_column :taxon_changes, :move_children, :boolean, default: false
    execute "UPDATE taxon_changes SET move_children = true"
  end
  def down
    remove_column :taxon_changes, :move_children
  end
end
