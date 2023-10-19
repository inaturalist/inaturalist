class AddPlatformsToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :platforms, :text, array: true, default: []
  end
end
