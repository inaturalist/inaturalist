class AddFeaturedAtToProjects < ActiveRecord::Migration
  def self.up
    add_column :projects, :featured_at, :datetime
  end

  def self.down
    remove_column :projects, :featured_at, :datetime
  end
end
