# frozen_string_literal: true

class AddTargetGroupsToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :target_group_type, :string
    add_column :announcements, :target_group_partition, :string
  end
end
