class AddBlindColsToIdentifications < ActiveRecord::Migration
  def change
    add_column :identifications, :blind, :boolean
    add_column :identifications, :previous_observation_taxon_id, :integer
    add_index :identifications, :previous_observation_taxon_id
  end
end
