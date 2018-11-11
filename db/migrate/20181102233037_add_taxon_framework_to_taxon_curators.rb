class AddTaxonFrameworkToTaxonCurators < ActiveRecord::Migration
  def change
    add_column :taxon_curators, :taxon_framework_id, :integer
    remove_column :taxon_curators, :taxon_id, :integer
    remove_column :taxa, :complete, :boolean
    remove_column :taxa, :complete_rank, :string
  end
end
