# frozen_string_literal: true

class CreateUserInstallationActivities < ActiveRecord::Migration[6.1]
  def change
    create_table :user_installation_activities do | t |
      # bigint to match user_installations.id, which is itself a bigint
      t.bigint :user_installation_id, null: false
      t.date :activity_date, null: false
    end

    # A row exists only for days the installation was seen active, so this index
    # is both the lookup path for per-installation history and the conflict
    # target that makes the daily import idempotent
    add_index :user_installation_activities,
      [:user_installation_id, :activity_date],
      unique: true,
      name: "index_user_installation_activities_on_installation_and_date"
    add_index :user_installation_activities, :activity_date,
      name: "index_user_installation_activities_on_activity_date"
  end
end
