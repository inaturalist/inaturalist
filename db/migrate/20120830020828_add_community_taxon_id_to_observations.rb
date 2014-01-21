class AddCommunityTaxonIdToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :community_taxon_id, :integer
    add_index :observations, :community_taxon_id
  end
end
