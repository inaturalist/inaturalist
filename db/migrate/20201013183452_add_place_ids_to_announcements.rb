class AddPlaceIdsToAnnouncements < ActiveRecord::Migration
  def change
    add_column :announcements, :place_ids, :integer, array: true, default: []
  end
end
