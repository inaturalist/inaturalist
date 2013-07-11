class AddObservationSounds < ActiveRecord::Migration
  def up
    rename_table :observations_sounds, :observation_sounds
    add_column :observations, :sounds_count, :integer, :default => 0
    execute <<-SQL
      UPDATE observations SET sounds_count = osc.sounds_count FROM (
        SELECT observation_id, count(*) AS sounds_count
        FROM observation_sounds
        GROUP BY observation_id
      ) AS osc
      WHERE osc.observation_id = observations.id
    SQL
  end

  def down
    rename_table :observation_sounds, :observations_sounds
    remove_column :observations, :sounds_count
  end
end
