class AddAutoJoinToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :auto_join, :boolean
  end

  def self.down
    remove_column :projects, :auto_join
  end
end
