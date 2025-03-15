# frozen_string_literal: true

class AddTargetLoggedInToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :target_logged_in, :string, default: "any"
  end
end
