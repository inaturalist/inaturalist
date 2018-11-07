class AddConceptToTaxonCurators < ActiveRecord::Migration
  def change
    add_column :taxon_curators, :concept_id, :integer
    remove_column :taxon_curators, :taxon_id, :integer
    remove_column :taxa, :complete, :boolean
  end
end
