class AddFileToPhotos < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      ALTER TABLE photos
        ADD COLUMN file_content_type VARCHAR(255),
        ADD COLUMN file_file_name VARCHAR(255),
        ADD COLUMN file_file_size INT(11)
    SQL
  end

  def self.down
    execute <<-SQL
      ALTER TABLE photos
        DROP COLUMN file_content_type,
        DROP COLUMN file_file_name,
        DROP COLUMN file_file_size
    SQL
  end
end
