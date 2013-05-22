class CreateGuidePhotos < ActiveRecord::Migration
  def change
    create_table :guide_photos do |t|
      t.integer :guide_taxon_id
      t.string :title
      t.string :description
      t.integer :photo_id

      t.timestamps
    end
    add_index :guide_photos, :guide_taxon_id
    add_index :guide_photos, :photo_id
  end
end
