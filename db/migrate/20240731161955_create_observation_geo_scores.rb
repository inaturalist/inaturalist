# frozen_string_literal: true

class CreateObservationGeoScores < ActiveRecord::Migration[6.1]
  def change
    create_table :observation_geo_scores do | t |
      t.integer :observation_id
      t.float :geo_score
    end

    add_index :observation_geo_scores, :observation_id, unique: true
  end
end
