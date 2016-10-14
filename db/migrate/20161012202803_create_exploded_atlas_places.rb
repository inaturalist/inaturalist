class CreateExplodedAtlasPlaces < ActiveRecord::Migration
  def change
    create_table :exploded_atlas_places do |t|
      t.references :atlas
      t.references :place
      t.timestamps null: false
    end
  end
end
