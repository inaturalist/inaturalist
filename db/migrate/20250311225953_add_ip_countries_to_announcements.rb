# frozen_string_literal: true

class AddIpCountriesToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :ip_countries, :text, array: true, default: []
  end
end
