class AddLastAggregatedAtToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :last_aggregated_at, :timestamp
  end
end
