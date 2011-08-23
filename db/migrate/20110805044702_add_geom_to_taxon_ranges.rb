class AddGeomToTaxonRanges < ActiveRecord::Migration
  def self.up
    add_column :taxon_ranges, :geom, :multi_polygon
    add_index :taxon_ranges, :geom, :spatial => true
  end

  def self.down
    remove_column :taxon_ranges, :geom
  end
end
