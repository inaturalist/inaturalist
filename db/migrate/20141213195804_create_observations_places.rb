class CreateObservationsPlaces < ActiveRecord::Migration

  def change
    create_table :observations_places do |t|
      t.integer :observation_id, null: false
      t.integer :place_id, null: false
    end
    add_index :observations_places, [ :observation_id, :place_id ], unique: true
    add_index :observations_places, :place_id
  end

end
