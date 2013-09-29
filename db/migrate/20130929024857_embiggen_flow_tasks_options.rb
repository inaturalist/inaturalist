class EmbiggenFlowTasksOptions < ActiveRecord::Migration
  def up
    change_column :flow_tasks, :options, :text
  end

  def down
    change_column :flow_tasks, :options, :string, :limit => 1024
  end
end
