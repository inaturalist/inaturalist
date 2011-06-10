class RemoveGeomFromTaxonRanges < ActiveRecord::Migration
  def self.up
    remove_column :taxon_ranges, :geom
  end

  def self.down
    add_column :taxon_ranges, :geom, :multi_polygon
  end
end
