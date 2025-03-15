# frozen_string_literal: true

class AddUserCreatedDatesToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :user_created_start_date, :date
    add_column :announcements, :user_created_end_date, :date
  end
end
