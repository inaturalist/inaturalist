class CreateDeletedPhotos < ActiveRecord::Migration
  def change
    create_table :deleted_photos do |t|
      t.integer :user_id
      t.integer :photo_id
      t.timestamps
    end
    add_index :deleted_photos, :created_at
  end
end
