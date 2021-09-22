class AddAttachmentsFaviconShareableToSites < ActiveRecord::Migration
  def self.up
    change_table :sites do |t|
      t.attachment :favicon
      t.attachment :shareable_image
    end
  end

  def self.down
    drop_attached_file :sites, :favicon
    drop_attached_file :sites, :shareable_image
  end
end
