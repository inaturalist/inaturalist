class AddDismissUserIdsToAnnouncements < ActiveRecord::Migration
  def change
    add_column :announcements, :dismiss_user_ids, :integer, array: true, default: []
    add_column :announcements, :dismissable, :boolean, default: false
  end
end
