class AddSourceToPlaces < ActiveRecord::Migration
  def change
    add_column :places, :source_id, :integer
    add_index :places, :source_id
    add_column :place_geometries, :source_id, :integer
    add_index :place_geometries, :source_id
  end
end
