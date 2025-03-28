# frozen_string_literal: true

class AddTargetProjectAdminsToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :target_project_admins, :string, default: "any"
  end
end
