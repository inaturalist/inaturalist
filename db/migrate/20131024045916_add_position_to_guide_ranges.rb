class AddPositionToGuideRanges < ActiveRecord::Migration
  def change
    add_column :guide_ranges, :position, :integer, :default => 0
  end
end
