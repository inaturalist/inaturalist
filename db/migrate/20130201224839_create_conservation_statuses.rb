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
      t.string :description
      t.string :geoprivacy, :default => "obscured"
      t.string :iucn

      t.timestamps
    end
    add_index :conservation_statuses, :taxon_id
    add_index :conservation_statuses, :user_id
    add_index :conservation_statuses, :place_id
    add_index :conservation_statuses, :source_id

    errors = 0
    Taxon.where("conservation_status IS NOT NULL").find_each do |taxon|
      cs = ConservationStatus.new(
        :taxon => taxon,
        :iucn => taxon.conservation_status,
        :status => taxon.conservation_status,
        :geoprivacy => (taxon.conservation_status >= Taxon::IUCN_NEAR_THREATENED),
        :authority => "IUCN Red List",
        :source_id => taxon.conservation_status_source_id
      )
      unless taxon.conservation_status_source_identifier.blank?
        cs.url = "http://www.iucnredlist.org/details/#{taxon.conservation_status_source_identifier}"
      end
      unless cs.save
        errors += 1
      end
    end
    if errors > 0
      puts "Failed to create IUCN ConservationStatuses for #{errors} taxa."
    end
  end

  def down
    drop_table :conservation_statuses
  end
end
