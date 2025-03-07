# frozen_string_literal: true

class AddObservationRangeToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :min_observations, :integer
    add_column :announcements, :max_observations, :integer
  end
end
