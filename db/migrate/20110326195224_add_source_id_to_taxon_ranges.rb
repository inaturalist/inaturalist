class AddSourceIdToTaxonRanges < ActiveRecord::Migration
  def self.up
    add_column :taxon_ranges, :source_id, :integer
  end

  def self.down
    remove_column :taxon_ranges, :source_id
  end
end
