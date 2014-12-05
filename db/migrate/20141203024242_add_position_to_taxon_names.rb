class AddPositionToTaxonNames < ActiveRecord::Migration
  def change
    add_column :taxon_names, :position, :integer, :default => 0
  end
end
