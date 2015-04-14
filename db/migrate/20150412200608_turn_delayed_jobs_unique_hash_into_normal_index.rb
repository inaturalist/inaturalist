class TurnDelayedJobsUniqueHashIntoNormalIndex < ActiveRecord::Migration
  def up
    remove_index :delayed_jobs, :unique_hash
    add_index :delayed_jobs, :unique_hash
  end

  def down
    remove_index :delayed_jobs, :unique_hash
    add_index :delayed_jobs, :unique_hash, unique: true
  end
end
