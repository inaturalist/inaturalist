class EmbiggenPhotoOriginalUrl < ActiveRecord::Migration
  def up
    change_column :photos, :original_url, :string, :limit => 512
  end

  def down
    change_column :photos, :original_url, :string, :limit => 256
  end
end
