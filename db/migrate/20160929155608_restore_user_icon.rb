class RestoreUserIcon < ActiveRecord::Migration
  def up
    rename_column :users, :s3_icon_file_name, :icon_file_name
    rename_column :users, :s3_icon_content_type, :icon_content_type
    rename_column :users, :s3_icon_file_size, :icon_file_size
    rename_column :users, :s3_icon_updated_at, :icon_updated_at

    remove_column :users, :local_icon_file_name
    remove_column :users, :local_icon_content_type
    remove_column :users, :local_icon_file_size
    remove_column :users, :local_icon_updated_at
    remove_column :users, :moved_to_s3
  end

  def down
    rename_column :users, :icon_file_name, :s3_icon_file_name
    rename_column :users, :icon_content_type, :s3_icon_content_type
    rename_column :users, :icon_file_size, :s3_icon_file_size
    rename_column :users, :icon_updated_at, :s3_icon_updated_at

    add_column :users, :local_icon_file_name, :string
    add_column :users, :local_icon_content_type, :string
    add_column :users, :local_icon_file_size, :integer
    add_column :users, :local_icon_updated_at, :datetime
    add_column :users, :moved_to_s3, :boolean, default: false
  end
end
