class AddRemotePhotoFieldsToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :subtype, :string, limit: 255
    add_column :photos, :native_original_image_url, :string, limit: 512
  end
end
