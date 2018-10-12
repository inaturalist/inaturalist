class CreateSiteFeaturedProjects < ActiveRecord::Migration
  def up
    create_table :site_featured_projects do |t|
      t.integer :site_id
      t.integer :project_id
      t.integer :user_id
      t.boolean :noteworthy, default: false
      t.timestamps
    end
    add_index :site_featured_projects, [ :site_id, :project_id ], unique: true

    # create SiteFeaturedProjects from existing featured projects, using the default site
    featured_by_user = ( User.where( login: "pleary" ).first || User.first )
    featured_projects = Project.where( "featured_at IS NOT NULL" )
    featured_projects.each do |p|
      SiteFeaturedProject.create(
        project: p,
        user: featured_by_user,
        created_at: p.featured_at,
        updated_at: p.featured_at,
        site: Site.default
      )
    end
    remove_column :projects, :featured_at
    Project.elastic_index!(ids: featured_projects.map(&:id))
  end


  def down
    add_column :projects, :featured_at, :datetime
    # set Project.featured_at based on SiteFeaturedProjects in the default site
    SiteFeaturedProject.where(site_id: 1).each do |sfp|
      Project.where(id: sfp.project_id).update_all(featured_at: sfp.created_at)
    end
    drop_table :site_featured_projects
  end
end
