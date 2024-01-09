# frozen_string_literal: true

class CreateObservationAccuracyValidator < ActiveRecord::Migration[6.1]
  def change
    create_table :observation_accuracy_validators do | t |
      t.integer :observation_accuracy_experiment_id
      t.integer :user_id
      t.integer :observation_id

      t.timestamps
    end

    add_index :observation_accuracy_validators, :observation_accuracy_experiment_id,
      name: "index_oav_on_oae_id"
  end
end
