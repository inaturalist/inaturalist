class AddUniqueUuidIndexes < ActiveRecord::Migration
  def up
    [
      :comments,
      :identifications,
      :observations,
      :observation_field_values,
      :observation_photos,
      :observation_sounds,
      :project_observations,
    ].each do |table|
      remove_index table, :uuid
      add_index table, :uuid, unique: true
    end
  end
  def down
    [
      :comments,
      :identifications,
      :observations,
      :observation_field_values,
      :observation_photos,
      :observation_sounds,
      :project_observations,
    ].each do |table|
      remove_index table, :uuid
      add_index table, :uuid
    end
  end
end
