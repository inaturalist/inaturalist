class AddIucnRelationshipToTaxonRanges < ActiveRecord::Migration[5.2]
  def change
    add_column :taxon_ranges, :iucn_relationship, :integer
  end
end
