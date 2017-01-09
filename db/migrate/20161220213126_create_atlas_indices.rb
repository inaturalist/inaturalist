class CreateAtlasIndices < ActiveRecord::Migration
  def change
    add_index :complete_sets, [:taxon_id, :place_id]
    add_index :exploded_atlas_places, [:atlas_id, :place_id]
  end
end
