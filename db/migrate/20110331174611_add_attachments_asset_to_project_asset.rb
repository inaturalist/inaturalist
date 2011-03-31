class AddAttachmentsAssetToProjectAsset < ActiveRecord::Migration
  def self.up
    add_column :project_assets, :asset_file_name, :string
    add_column :project_assets, :asset_content_type, :string
    add_column :project_assets, :asset_file_size, :integer
    add_column :project_assets, :asset_updated_at, :datetime
    add_index :project_assets, :asset_content_type
  end

  def self.down
    remove_column :project_assets, :asset_file_name
    remove_column :project_assets, :asset_content_type
    remove_column :project_assets, :asset_file_size
    remove_column :project_assets, :asset_updated_at
  end
end
