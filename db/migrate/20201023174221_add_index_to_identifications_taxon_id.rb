class AddIndexToIdentificationsTaxonId < ActiveRecord::Migration
  def change
    add_index :identifications, :taxon_id
  end
end
