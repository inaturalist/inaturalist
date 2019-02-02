require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "relationship" do
  it "should update relationship when external taxon destroyed" do
    tfr = TaxonFrameworkRelationship.make!
    t = Taxon.make!(name: "Taricha torosa", rank: "species")
    t.parent = tfr.taxon_framework.taxon
    t.save
    t.update_attributes( taxon_framework_relationship_id: tfr.id )
    t.reload
    et = ExternalTaxon.new(name: "Taricha torosa", rank: "species", parent_name: t.parent.name, parent_rank: t.parent.rank, taxon_framework_relationship_id: tfr.id)
    et.save
    tfr.reload
    expect(tfr.relationship).to eq "match"
    et.destroy
    tfr.reload
    expect(tfr.relationship).to eq "not_external"
  end
end