class AddAttachmentLogoEmailBannerToSites < ActiveRecord::Migration
  def self.up
    change_table :sites do |t|
      t.attachment :logo_email_banner
    end
  end

  def self.down
    remove_attachment :sites, :logo_email_banner
  end
end
