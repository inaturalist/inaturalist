class AddProjectTypeToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :project_type, :string
  end

  def self.down
    remove_column :projects, :project_type
  end
end
