class RemovePhotoUrlColumns < ActiveRecord::Migration[5.2]
  def up
    add_column :photos, :original_url, :string, limit: 512
    add_column :photos, :large_url, :string, limit: 512
    add_column :photos, :medium_url, :string, limit: 512
    add_column :photos, :small_url, :string, limit: 512
    add_column :photos, :thumb_url, :string, limit: 512
    add_column :photos, :square_url, :string, limit: 512
  end

  def down
    remove_column :projects, :original_url
    remove_column :projects, :large_url
    remove_column :projects, :medium_url
    remove_column :projects, :small_url
    remove_column :projects, :thumb_url
    remove_column :projects, :square_url
  end
end
