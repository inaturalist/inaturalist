# frozen_string_literal: true

class AddObservationCreatedAtToDeletedObservation < ActiveRecord::Migration[6.1]
  def change
    add_column :deleted_observations, :observation_created_at, :datetime
  end
end
