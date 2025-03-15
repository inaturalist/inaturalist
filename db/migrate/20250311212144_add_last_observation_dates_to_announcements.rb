# frozen_string_literal: true

class AddLastObservationDatesToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :last_observation_start_date, :date
    add_column :announcements, :last_observation_end_date, :date
  end
end
