class EmbiggenFlowTaskOptions < ActiveRecord::Migration
  def up
    change_column :flow_tasks, :options, :string, :limit => 1024
  end

  def down
    change_column :flow_tasks, :options, :string, :limit => 256
  end
end
