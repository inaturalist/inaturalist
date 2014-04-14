class EmbiggenGuideUrls < ActiveRecord::Migration
  def up
    change_column :guide_ranges, :original_url, :string, :limit => 512
    change_column :guide_ranges, :medium_url, :string, :limit => 512
    change_column :guide_ranges, :thumb_url, :string, :limit => 512
    change_column :guide_ranges, :source_url, :string, :limit => 512
  end

  def down
    change_column :guide_ranges, :original_url, :string, :limit => 256
    change_column :guide_ranges, :medium_url, :string, :limit => 256
    change_column :guide_ranges, :thumb_url, :string, :limit => 256
    change_column :guide_ranges, :source_url, :string, :limit => 256
  end
end
