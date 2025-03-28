# frozen_string_literal: true

class AddObservationOauthAppIdsToAnnouncements < ActiveRecord::Migration[6.1]
  def change
    add_column :announcements, :include_observation_oauth_application_ids, :integer, array: true, default: []
    add_column :announcements, :exclude_observation_oauth_application_ids, :integer, array: true, default: []
  end
end
