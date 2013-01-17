class AddDeltaToProjects < ActiveRecord::Migration
  def change
    add_column :projects, "delta", :boolean, :default => false
  end
end
