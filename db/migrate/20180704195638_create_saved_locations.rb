class CreateSavedLocations < ActiveRecord::Migration
  def change
    create_table :saved_locations do |t|
      t.integer :user_id
      t.decimal :latitude, precision: 15, scale: 10
      t.decimal :longitude, precision: 15, scale: 10
      t.string :title
      t.integer :positional_accuracy

      t.timestamps null: false
    end
    add_index :saved_locations, :user_id
  end
end
