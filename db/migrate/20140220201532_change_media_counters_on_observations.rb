class ChangeMediaCountersOnObservations < ActiveRecord::Migration
  def up
    rename_column :observations, :photos_count, :observation_photos_count
    rename_column :observations, :sounds_count, :observation_sounds_count
  end

  def down
    rename_column :observations, :observation_photos_count, :photos_count
    rename_column :observations, :observation_sounds_count, :sounds_count
  end
end
