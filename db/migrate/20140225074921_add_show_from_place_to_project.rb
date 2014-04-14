class AddShowFromPlaceToProject < ActiveRecord::Migration
  def up
    add_column :projects, :show_from_place, :boolean
  end

  def down
    remove_column :projects, :show_from_place    
  end
end
