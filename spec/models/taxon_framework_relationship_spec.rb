require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "relationship" do
  it "should update relationship when external taxon destroyed" do
    tfr = TaxonFrameworkRelationship.make!
    p = Taxon.make!(name: "Taricha", rank: "genus")
    t = Taxon.make!(name: "Taricha torosa", rank: "species", taxon_framework_relationship_id: tfr.id)
    t.parent = p
    t.save
    t.reload
    et = ExternalTaxon.new(name: "Taricha torosa", rank: "species", parent_name: "Taricha", parent_rank: "genus", taxon_framework_relationship_id: tfr.id)
    et.save
    tfr.reload
    expect(tfr.relationship).to eq "match"
    et.destroy
    tfr.reload
    expect(tfr.relationship).to eq "not_external"
  end
end