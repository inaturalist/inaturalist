class AddPositionToMoreGuideStuff < ActiveRecord::Migration
  def change
    add_column :guide_photos, :position, :integer, :default => 0
    add_column :guide_sections, :position, :integer, :default => 0
  end
end
