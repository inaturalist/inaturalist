class TransitionUserIcon < ActiveRecord::Migration
  def change
    rename_column :users, :icon_file_name, :local_icon_file_name
    rename_column :users, :icon_content_type, :local_icon_content_type
    rename_column :users, :icon_file_size, :local_icon_file_size
    rename_column :users, :icon_updated_at, :local_icon_updated_at

    add_column :users, :s3_icon_file_name, :string
    add_column :users, :s3_icon_content_type, :string
    add_column :users, :s3_icon_file_size, :integer
    add_column :users, :s3_icon_updated_at, :datetime
    add_column :users, :moved_to_s3, :boolean, default: false
  end
end
