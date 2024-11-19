class AddClientsToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :clients, :text, array: true, default: []
  end
end
