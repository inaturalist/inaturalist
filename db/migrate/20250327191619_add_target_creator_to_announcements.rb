# frozen_string_literal: true

class AddTargetCreatorToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :target_creator, :boolean, default: false
  end
end
