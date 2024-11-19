# frozen_string_literal: true

class CreateObservationAccuracyValidator < ActiveRecord::Migration[6.1]
  def change
    create_table :observation_accuracy_validators do | t |
      t.integer :observation_accuracy_experiment_id
      t.integer :user_id
      t.datetime :email_date

      t.timestamps
    end

    add_index :observation_accuracy_validators, [:user_id, :observation_accuracy_experiment_id], unique: true,
      name: "index_oav_on_oae_id_uid"
  end
end
