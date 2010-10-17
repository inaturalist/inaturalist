class AddProjectIdToLists < ActiveRecord::Migration
  def self.up
    add_column :lists, :project_id, :integer
    add_index :lists, :project_id
  end

  def self.down
    remove_column :lists, :project_id
  end
end
