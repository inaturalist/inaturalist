class CreateExplodedAtlasPlaces < ActiveRecord::Migration
  def change
    create_table :exploded_atlas_places do |t|
      t.references :atlas, index: true
      t.references :place, index: true
      t.timestamps null: false
    end
  end
end
