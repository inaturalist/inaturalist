class CreateAnnouncementsSites < ActiveRecord::Migration
  def up
    create_table :announcements_sites, id: false do |t|
      t.belongs_to :announcement, index: true
      t.belongs_to :site, index: true
    end
    Announcement.find_each do |a|
      if site = Site.find_by_id( a.site_id )
        a.sites << site
      end
    end
    remove_column :announcements, :site_id
  end

  def down
    add_column :announcements, :site_id, :integer, index: true
    execute <<-SQL
      UPDATE announcements
      SET site_id = announcements_sites.site_id
      FROM announcements_sites
      WHERE announcements_sites.announcement_id = announcements.id
    SQL
    drop_table :announcements_sites
  end
end
