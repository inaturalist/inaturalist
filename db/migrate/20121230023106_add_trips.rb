class AddTrips < ActiveRecord::Migration
  def change
    add_column :posts, :type, :string
    add_column :posts, :start_time, :datetime
    add_column :posts, :stop_time, :datetime
    add_column :posts, :place_id, :integer
    add_column :posts, :latitude, :decimal, :precision => 15, :scale => 10
    add_column :posts, :longitude, :decimal, :precision => 15, :scale => 10
    add_column :posts, :positional_accuracy, :integer
    add_index :posts, :place_id

    create_table :trip_taxa do |t|
      t.integer :taxon_id
      t.integer :trip_id
      t.boolean :observed
    end
    add_index :trip_taxa, :taxon_id
    add_index :trip_taxa, :trip_id

    create_table :trip_purposes do |t|
      t.integer :trip_id
      t.string :purpose
      t.string :resource_type
      t.integer :resource_id
      t.boolean :success
    end
    add_index :trip_purposes, :trip_id
    add_index :trip_purposes, [:resource_type, :resource_id]
  end
end
