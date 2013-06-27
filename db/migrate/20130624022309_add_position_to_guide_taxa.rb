class AddPositionToGuideTaxa < ActiveRecord::Migration
  def change
    add_column :guide_taxa, :position, :integer, :default => 0
  end
end
