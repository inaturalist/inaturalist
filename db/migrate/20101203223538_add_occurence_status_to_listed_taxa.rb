class AddOccurenceStatusToListedTaxa < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      ALTER TABLE listed_taxa
        ADD COLUMN occurrence_status_level INT(11),
        ADD COLUMN establishment_means VARCHAR(32)
    SQL
  end

  def self.down
    execute <<-SQL
      ALTER TABLE listed_taxa
        DROP COLUMN occurrence_status_level,
        DROP COLUMN establishment_means
    SQL
  end
end
