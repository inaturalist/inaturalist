class AddAttachmentsLogoBlogToSites < ActiveRecord::Migration
  def self.up
    change_table :sites do |t|
      t.attachment :logo_blog
    end
  end

  def self.down
    drop_attached_file :sites, :logo_blog
  end
end
