class AddExtraPlaceIdToSites < ActiveRecord::Migration
  def change
    add_column :sites, :extra_place_id, :integer
  end
end
