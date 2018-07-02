class AddIndexToObservationFieldsValueAndObservationFieldId < ActiveRecord::Migration
  def change
    add_index :observation_field_values, [:value, :observation_field_id], name: "index_observation_field_values_on_value_and_field"
  end
end
