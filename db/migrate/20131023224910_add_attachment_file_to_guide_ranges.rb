class AddAttachmentFileToGuideRanges < ActiveRecord::Migration
  def self.up
    change_table :guide_ranges do |t|
      t.attachment :file
    end
  end

  def self.down
    drop_attached_file :guide_ranges, :file
  end
end
