class AddAttachmentsIconToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :icon_file_name, :string
    add_column :projects, :icon_content_type, :string
    add_column :projects, :icon_file_size, :integer
    add_column :projects, :icon_updated_at, :datetime
  end

  def self.down
    remove_column :projects, :icon_file_name
    remove_column :projects, :icon_content_type
    remove_column :projects, :icon_file_size
    remove_column :projects, :icon_updated_at
  end
end
