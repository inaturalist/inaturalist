class AddAttachmentLogoLogoSquareToSites < ActiveRecord::Migration
  def self.up
    change_table :sites do |t|
      t.attachment :logo
      t.attachment :logo_square
    end
  end

  def self.down
    drop_attached_file :sites, :logo
    drop_attached_file :sites, :logo_square
  end
end
