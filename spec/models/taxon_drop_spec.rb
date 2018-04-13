require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonDrop, "commit" do
  before(:each) do
    prepare_drop
    @drop.committer = @drop.user
  end

  it "should mark input taxon as active" do
    expect( @input_taxon ).to be_is_active
    @drop.commit
    @input_taxon.reload
    expect( @input_taxon ).not_to be_is_active
  end
end

describe TaxonDrop, "commit_records" do
  before(:each) { prepare_drop }
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }

  it "should not update records" do
    obs = Observation.make!( taxon: @input_taxon )
    @drop.commit_records
    obs.reload
    expect( obs.taxon ).to eq( @input_taxon )
  end
end

def prepare_drop
  @input_taxon = Taxon.make!( rank: Taxon::FAMILY )
  @drop = TaxonDrop.make
  @drop.add_input_taxon( @input_taxon )
  @drop.save!  
end
