class AddAttachmentIconToGuides < ActiveRecord::Migration
  def self.up
    change_table :guides do |t|
      t.attachment :icon
    end
  end

  def self.down
    drop_attached_file :guides, :icon
  end
end
