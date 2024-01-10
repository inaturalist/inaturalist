# frozen_string_literal: true

class CreateObservationAccuracyValidator < ActiveRecord::Migration[6.1]
  def change
    create_table :observation_accuracy_validators do | t |
      t.integer :user_id
      t.datetime :email_date

      t.timestamps
    end

    add_index :observation_accuracy_validators, :user_id
  end
end
