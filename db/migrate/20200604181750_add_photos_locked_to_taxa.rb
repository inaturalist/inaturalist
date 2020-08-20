class AddPhotosLockedToTaxa < ActiveRecord::Migration
  def change
    add_column :taxa, :photos_locked, :boolean, default: false
  end
end
