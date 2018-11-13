class AddTaxonFrameworkRelationshipRefToTaxa < ActiveRecord::Migration
  def change
    add_reference :taxa, :taxon_framework_relationship, index: true
  end
end
