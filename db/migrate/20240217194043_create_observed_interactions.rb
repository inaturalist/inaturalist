# frozen_string_literal: true

class CreateObservedInteractions < ActiveRecord::Migration[6.1]
  def change
    create_table :observed_interactions do | t |
      t.integer :subject_observation_id
      t.integer :object_observation_id
      t.integer :user_id

      t.timestamps
    end
  end
end
