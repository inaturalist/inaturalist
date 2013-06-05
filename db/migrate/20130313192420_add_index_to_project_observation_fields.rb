class AddIndexToProjectObservationFields < ActiveRecord::Migration
  def change
    add_index :project_observation_fields, :observation_field_id
  end
end
