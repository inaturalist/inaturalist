class AddAttachmentShareableImageToYearStatistics < ActiveRecord::Migration
  def self.up
    change_table :year_statistics do |t|
      t.attachment :shareable_image
    end
  end

  def self.down
    remove_attachment :year_statistics, :shareable_image
  end
end
