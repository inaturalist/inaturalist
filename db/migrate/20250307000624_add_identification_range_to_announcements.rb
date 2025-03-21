# frozen_string_literal: true

class AddIdentificationRangeToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :min_identifications, :integer
    add_column :announcements, :max_identifications, :integer
  end
end
