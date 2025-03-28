# frozen_string_literal: true

class AddTargetCuratorsToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :target_curators, :string, default: "any"
  end
end
