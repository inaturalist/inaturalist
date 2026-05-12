# frozen_string_literal: true

class AddParentAnnouncementIdToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :parent_announcement_id, :integer
    add_index :announcements, :parent_announcement_id
    add_foreign_key :announcements, :announcements, column: :parent_announcement_id, on_delete: :nullify
  end
end
