class RemoveAutoJoinFromProjects < ActiveRecord::Migration
  def self.up
    remove_column :projects, :auto_join
  end

  def self.down
    add_column :projects, :auto_join, :boolean
  end
end
