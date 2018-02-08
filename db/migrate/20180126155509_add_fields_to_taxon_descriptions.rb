class AddFieldsToTaxonDescriptions < ActiveRecord::Migration
  def change
    add_column :taxon_descriptions, :provider, :string
    add_column :taxon_descriptions, :provider_taxon_id, :string
    add_column :taxon_descriptions, :url, :string
    add_index :taxon_descriptions, :provider
  end
end
