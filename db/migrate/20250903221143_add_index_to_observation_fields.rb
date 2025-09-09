# frozen_string_literal: true

class AddIndexToObservationFields < ActiveRecord::Migration[6.1]
  def change
    add_index :observation_field_values, [:observation_field_id, :id]
  end
end
