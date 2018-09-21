class CreateSiteFeaturedProjects < ActiveRecord::Migration
  def change
    create_table :site_featured_projects do |t|
      t.integer :site_id
      t.integer :project_id
      t.integer :user_id
      t.boolean :noteworthy, default: false
      t.timestamps
    end
    add_index :site_featured_projects, [ :site_id, :project_id ], unique: true
  end
end
