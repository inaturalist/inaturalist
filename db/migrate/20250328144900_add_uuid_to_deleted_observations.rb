# frozen_string_literal: true

class AddUuidToDeletedObservations < ActiveRecord::Migration[6.1]
  def change
    add_column :deleted_observations, :observation_uuid, :uuid
    add_index :deleted_observations, :observation_uuid
    add_index :deleted_observations, :observation_id
  end
end
