class AddGeoprivacyToSavedLocations < ActiveRecord::Migration
  def change
    add_column :saved_locations, :geoprivacy, :text, default: "open"
    add_index :saved_locations, :title
  end
end
