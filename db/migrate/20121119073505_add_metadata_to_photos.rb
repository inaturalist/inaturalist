class AddMetadataToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :metadata, :text
  end
end
