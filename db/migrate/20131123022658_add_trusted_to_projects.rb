class AddTrustedToProjects < ActiveRecord::Migration
  def up
    add_column :projects, :trusted, :boolean, default: false
  end

  def down
    remove_column :projects, :trusted
  end
end

