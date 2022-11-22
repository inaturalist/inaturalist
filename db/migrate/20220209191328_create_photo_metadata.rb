class CreatePhotoMetadata < ActiveRecord::Migration[6.1]
  def change
    create_table :photo_metadata, id: false do |t|
      t.integer :photo_id, null: false
      t.binary :metadata
    end
    add_index :photo_metadata, :photo_id, unique: true
  end
end
