class AddAttachmentHomepageDataToSites < ActiveRecord::Migration
  def self.up
    change_table :sites do |t|
      t.attachment :homepage_data
    end
  end

  def self.down
    drop_attached_file :sites, :homepage_data
  end
end
