class AddSiteIdToAnnouncements < ActiveRecord::Migration
  def change
    add_column :announcements, :site_id, :integer
    add_index :announcements, :site_id
  end
end
