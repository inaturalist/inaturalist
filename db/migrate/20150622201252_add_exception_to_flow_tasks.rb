class AddExceptionToFlowTasks < ActiveRecord::Migration
  def change
    add_column :flow_tasks, :exception, :text
  end
end
