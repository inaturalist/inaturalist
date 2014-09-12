class AddAttachmentStylesheetToSites < ActiveRecord::Migration
  def self.up
    change_table :sites do |t|
      t.attachment :stylesheet
    end
  end

  def self.down
    drop_attached_file :sites, :stylesheet
  end
end
