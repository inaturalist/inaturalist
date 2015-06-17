class AddVoteCacheColumnsToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :cached_votes_total, :integer, :default => 0
    add_index  :observations, :cached_votes_total
  end
end
