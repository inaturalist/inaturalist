class AddLastIndexedAtToObservations < ActiveRecord::Migration
  def up
    add_column :observations, :last_indexed_at, :datetime
    Observation.update_all(last_indexed_at: Time.now)
    add_index :observations, :last_indexed_at
  end

  def down
    remove_column :observations, :last_indexed_at
  end
end
