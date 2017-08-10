class AddFileAttachmentToSounds < ActiveRecord::Migration
  def self.up
    change_table :sounds do |t|
      t.attachment :file
    end
  end

  def self.down
    drop_attached_file :sounds, :file
  end
end
