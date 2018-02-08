class AddUniqueHashToFlowTasks < ActiveRecord::Migration
  def change
    add_column :flow_tasks, :unique_hash, :string
    add_index :flow_tasks, :unique_hash
  end
end
