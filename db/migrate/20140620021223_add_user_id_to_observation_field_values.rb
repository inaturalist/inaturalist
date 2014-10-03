class AddUserIdToObservationFieldValues < ActiveRecord::Migration
  def change
    add_column :observation_field_values, :user_id, :integer
    add_column :observation_field_values, :updater_id, :integer
    add_index :observation_field_values, :user_id
    add_index :observation_field_values, :updater_id
    execute <<-SQL
      UPDATE observation_field_values
      SET user_id = observations.user_id, updater_id = observations.user_id
      FROM observations
      WHERE observation_field_values.observation_id = observations.id
    SQL
  end
end
