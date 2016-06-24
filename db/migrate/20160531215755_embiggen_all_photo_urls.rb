class EmbiggenAllPhotoUrls < ActiveRecord::Migration
  def up
    change_column :photos, :square_url, :string, limit: 512
    change_column :photos, :thumb_url, :string, limit: 512
    change_column :photos, :small_url, :string, limit: 512
    change_column :photos, :medium_url, :string, limit: 512
    change_column :photos, :large_url, :string, limit: 512
    change_column :photos, :native_page_url, :string, limit: 512
  end

  def down
    change_column :photos, :square_url, :string, limit: 256
    change_column :photos, :thumb_url, :string, limit: 256
    change_column :photos, :small_url, :string, limit: 256
    change_column :photos, :medium_url, :string, limit: 256
    change_column :photos, :large_url, :string, limit: 256
    change_column :photos, :native_page_url, :string, limit: 256
  end
end
