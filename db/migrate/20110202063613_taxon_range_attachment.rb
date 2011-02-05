class TaxonRangeAttachment < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      ALTER TABLE taxon_ranges
        ADD COLUMN range_content_type VARCHAR(255),
        ADD COLUMN range_file_name VARCHAR(255),
        ADD COLUMN range_file_size INT(11),
        ADD COLUMN description TEXT,
        MODIFY COLUMN geom multipolygon NULL
    SQL
  end

  def self.down
    execute <<-SQL
      ALTER TABLE taxon_ranges
        DROP COLUMN range_content_type,
        DROP COLUMN range_file_name,
        DROP COLUMN range_file_size,
        DROP COLUMN description,
        MODIFY COLUMN geom multipolygon NOT NULL
    SQL
  end
end
