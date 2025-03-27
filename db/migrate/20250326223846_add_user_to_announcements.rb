# frozen_string_literal: true

class AddUserToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :user_id, :integer
    add_index :announcements, :user_id
  end
end
