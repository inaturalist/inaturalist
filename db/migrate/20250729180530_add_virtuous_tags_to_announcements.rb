# frozen_string_literal: true

class AddVirtuousTagsToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :include_virtuous_tags, :text, array: true, default: []
    add_column :announcements, :exclude_virtuous_tags, :text, array: true, default: []
  end
end
