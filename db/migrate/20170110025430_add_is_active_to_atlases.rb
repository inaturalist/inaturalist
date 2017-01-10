class AddIsActiveToAtlases < ActiveRecord::Migration
  def change
    add_column :atlases, :is_active, :boolean, default: false
  end
end
