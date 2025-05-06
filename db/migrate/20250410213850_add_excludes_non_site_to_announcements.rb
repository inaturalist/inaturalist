# frozen_string_literal: true

class AddExcludesNonSiteToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :excludes_non_site, :boolean, default: false
  end
end
