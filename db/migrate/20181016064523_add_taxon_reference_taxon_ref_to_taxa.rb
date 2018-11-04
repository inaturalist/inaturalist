class AddTaxonReferenceTaxonRefToTaxa < ActiveRecord::Migration
  def change
    add_reference :taxa, :taxon_reference, index: true, foreign_key: true
  end
end
