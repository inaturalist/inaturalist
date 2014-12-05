class CreatePlaceTaxonNames < ActiveRecord::Migration
  def up
    create_table :place_taxon_names do |t|
      t.integer :place_id
      t.integer :taxon_name_id
      t.integer :position, :default => 0
    end
    add_index :place_taxon_names, :place_id
    add_index :place_taxon_names, :taxon_name_id
  end

  def down
    drop_table :place_taxon_names
  end
end
