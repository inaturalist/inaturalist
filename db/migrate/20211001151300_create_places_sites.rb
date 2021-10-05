class CreatePlacesSites < ActiveRecord::Migration[5.2]
  def up
    create_table :places_sites do |t|
      t.integer :site_id, null: false
      t.integer :place_id, null: false
      t.string :scope, null: false
      t.timestamps
    end
    add_index :places_sites, :site_id
    Site.where.not( extra_place_id: nil ).each do |site|
      PlacesSite.create( site_id: site.id, place_id: site.extra_place_id, scope: PlacesSite::EXPORTS )
    end
    remove_column :sites, :extra_place_id
  end

  def down
    add_column :sites, :extra_place_id, :integer
    PlacesSite.all.each do |places_site|
      Site.where( id: places_site.site_id, extra_place_id: nil )
        .update_all( extra_place_id: places_site.place_id )
    end
    drop_table :places_sites
  end
end
