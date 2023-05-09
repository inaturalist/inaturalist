class AddFieldsToPhotos < ActiveRecord::Migration[5.2]
  def change
    add_column :photos, :file_extension_id, :integer, limit: 2
    add_column :photos, :file_prefix_id, :integer, limit: 2
    add_column :photos, :width, :integer, limit: 2
    add_column :photos, :height, :integer, limit: 2
  end
end
