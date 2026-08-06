# frozen_string_literal: true

# One row per day an installation was seen in the Kibana logs. There is no
# The presence of a row means active, its absence means inactive.
class UserInstallationActivity < ApplicationRecord
  belongs_to :user_installation

  UNIQUE_INDEX_NAME = "index_user_installation_activities_on_installation_and_date"

  # Records the given installations as active on activity_date, ignoring
  # installations already recorded for that date
  def self.record_activity( user_installations, activity_date )
    rows = user_installations.reject( &:new_record? ).map do | user_installation |
      {
        user_installation_id: user_installation.id,
        activity_date: activity_date
      }
    end
    return if rows.empty?

    insert_all( rows, unique_by: UNIQUE_INDEX_NAME )
  end
end
