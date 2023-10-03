class AddIndexOnObservationFieldValueIdToAnnotations < ActiveRecord::Migration[6.1]
  def change
    add_index :annotations, [:observation_field_value_id]
  end
end
