class AddIndexToDelayedJobsHandler < ActiveRecord::Migration
  def change
    add_column :delayed_jobs, :unique_hash, :string
    add_index :delayed_jobs, :unique_hash, unique: true
  end
end
