class AddAttachmentNgzToGuides < ActiveRecord::Migration
  def self.up
    change_table :guides do |t|
      t.attachment :ngz
    end
  end

  def self.down
    drop_attached_file :guides, :ngz
  end
end
