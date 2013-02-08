class AddShowObsPhotosToLists < ActiveRecord::Migration
  def up
    add_column :lists, :show_obs_photos, :boolean, :default => true
  end
  
  def down
    remove_column :lists, :show_obs_photos
  end
end
