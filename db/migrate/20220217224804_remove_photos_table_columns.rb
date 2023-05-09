class RemovePhotosTableColumns < ActiveRecord::Migration[6.1]
  def up
    remove_column :photos, :original_url
    remove_column :photos, :large_url
    remove_column :photos, :medium_url
    remove_column :photos, :small_url
    remove_column :photos, :square_url
    remove_column :photos, :thumb_url
    remove_column :photos, :metadata
  end

  def down
    add_column :photos, :original_url, :string, limit: 512
    add_column :photos, :large_url, :string, limit: 512
    add_column :photos, :medium_url, :string, limit: 512
    add_column :photos, :small_url, :string, limit: 512
    add_column :photos, :square_url, :string, limit: 512
    add_column :photos, :thumb_url, :string, limit: 512
    add_column :photos, :metadata, :text
  end
end
