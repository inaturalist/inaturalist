class AddFileProcessingToPhotos < ActiveRecord::Migration
  def self.up
    add_column :photos, :file_processing, :boolean
  end

  def self.down
    remove_column :photos, :file_processing
  end
end
