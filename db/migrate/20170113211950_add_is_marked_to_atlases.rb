class AddIsMarkedToAtlases < ActiveRecord::Migration
  def change
    add_column :atlases, :is_marked, :boolean, default: false
  end
end
