class AddGroupToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :group, :string
  end
end
