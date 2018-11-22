class AddTaxonGeoprivacyToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :taxon_geoprivacy, :string, length: 16
  end
end
