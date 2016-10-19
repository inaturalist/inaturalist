class CreateExplodedAtlasPlaces < ActiveRecord::Migration
  def change
    create_table :exploded_atlas_places do |t|
      t.references :atlas
      t.references :place
      t.timestamps null: false
    end
    add_index :atlas_id
    add_index :place_id
  end
end
