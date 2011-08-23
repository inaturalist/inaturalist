class AddSourceIdentifierToTaxonRanges < ActiveRecord::Migration
  def self.up
    add_column :taxon_ranges, :source_identifier, :integer
  end

  def self.down
    remove_column :taxon_ranges, :source_identifier
  end
end
