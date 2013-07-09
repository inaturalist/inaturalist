class AddSpatialColsToGuides < ActiveRecord::Migration
  def change
  	add_column :guides, :map_type, :string, :default => "terrain"
  	add_column :guides, :zoom_level, :integer
  end
end
