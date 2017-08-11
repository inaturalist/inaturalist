class AddFieldsToObservationSounds < ActiveRecord::Migration
  def up
    add_column :observation_sounds, :uuid, :uuid, default: "uuid_generate_v4()"
    add_index :observation_sounds, :uuid
    add_timestamps :observation_sounds
    execute <<-SQL
      UPDATE observation_sounds
      SET created_at = sounds.created_at, updated_at = sounds.updated_at
      FROM sounds
      WHERE observation_sounds.sound_id = sounds.id
    SQL
  end

  def down
    remove_column :observation_sounds, :uuid
    remove_column :observation_sounds, :created_at
    remove_column :observation_sounds, :updated_at
  end
end
