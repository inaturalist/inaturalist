# frozen_string_literal: true

class AddDonorDatesToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :include_donor_start_date, :date
    add_column :announcements, :include_donor_end_date, :date
    add_column :announcements, :exclude_donor_start_date, :date
    add_column :announcements, :exclude_donor_end_date, :date
  end
end
