class AddFieldsToDeletedPhotos < ActiveRecord::Migration
  def change
    add_column :deleted_photos, :removed_from_s3, :boolean, default: false, null: false
    add_column :deleted_photos, :orphan, :boolean, default: false, null: false
  end
end
