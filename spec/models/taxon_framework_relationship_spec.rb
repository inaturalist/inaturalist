require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonFrameworkRelationship do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :taxon_framework }
  it { is_expected.to have_many(:external_taxa).dependent :destroy }
  it { is_expected.to have_many(:taxa).dependent :nullify }

  describe "relationship" do
    it "should update relationship when external taxon destroyed" do
      genus = Taxon.make!( rank: Taxon::GENUS )
      species = Taxon.make!( rank: Taxon::SPECIES )
      species.update( parent: genus )
      tf = TaxonFramework.make!( taxon: genus )
      tfr = TaxonFrameworkRelationship.make!( taxon_framework: tf )
      species.update( taxon_framework_relationship_id: tfr.id )
      species.reload
      et = ExternalTaxon.new(
        name: species.name,
        rank: "species",
        parent_name: species.parent.name,
        parent_rank: species.parent.rank,
        taxon_framework_relationship_id: tfr.id
      )
      et.save
      tfr.reload
      expect( tfr.relationship ).to eq "match"
      et.destroy
      tfr.reload
      expect( tfr.relationship ).to eq "not_external"
    end
  end
end
