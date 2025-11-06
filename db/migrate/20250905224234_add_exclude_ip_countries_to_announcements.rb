# frozen_string_literal: true

class AddExcludeIpCountriesToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :exclude_ip_countries, :string, array: true, default: []
  end
end
