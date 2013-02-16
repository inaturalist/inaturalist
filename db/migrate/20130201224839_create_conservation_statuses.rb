class CreateConservationStatuses < ActiveRecord::Migration
  def up
    create_table :conservation_statuses do |t|
      t.integer :taxon_id
      t.integer :user_id
      t.integer :place_id
      t.integer :source_id
      t.string :authority
      t.string :status
      t.string :url
      t.text :description
      t.string :geoprivacy, :default => "obscured"
      t.integer :iucn, :default => Taxon::IUCN_NEAR_THREATENED

      t.timestamps
    end
    add_index :conservation_statuses, :taxon_id
    add_index :conservation_statuses, :user_id
    add_index :conservation_statuses, :place_id
    add_index :conservation_statuses, :source_id
  end

  def down
    drop_table :conservation_statuses
  end
end
