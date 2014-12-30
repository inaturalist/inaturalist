class AddAdminLevelToPlaces < ActiveRecord::Migration
  def up
    add_column :places, :admin_level, :integer
    add_index :places, :admin_level
    # match admin levels to GADM and GeoPlanet
    execute "UPDATE places SET admin_level = 0 WHERE place_type = 12" # country
    execute "UPDATE places SET admin_level = 1 WHERE place_type = 8"  # state
    execute "UPDATE places SET admin_level = 2 WHERE place_type = 9"  # county
    execute "UPDATE places SET admin_level = 3 WHERE place_type = 7"  # town
  end

  def down
    remove_column :places, :admin_level
  end
end
