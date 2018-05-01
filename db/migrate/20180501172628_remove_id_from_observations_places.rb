class RemoveIdFromObservationsPlaces < ActiveRecord::Migration
  def up
    remove_column :observations_places, :id
  end

  def down
    add_column :observations_places, :id, :primary_key
  end
end
