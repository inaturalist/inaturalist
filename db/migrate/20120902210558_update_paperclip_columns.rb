class UpdatePaperclipColumns < ActiveRecord::Migration
  def change
    add_column :photos, :file_updated_at, :datetime
    add_column :taxon_ranges, :range_updated_at, :datetime
    add_column :users, :icon_updated_at, :datetime
  end
end
