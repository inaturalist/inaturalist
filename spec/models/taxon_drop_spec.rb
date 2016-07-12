require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonDrop, "commit" do
  before(:each) do
    prepare_drop
  end

  it "should mark input taxon as active" do
    @input_taxon.should be_is_active
    @drop.commit
    @input_taxon.reload
    @input_taxon.should_not be_is_active
  end
end

describe TaxonSplit, "commit_records" do
  before(:each) { prepare_drop }
  it "should not update records" do
    obs = Observation.make!(:taxon => @input_taxon)
    @drop.commit_records
    obs.reload
    obs.taxon.should eq(@input_taxon)
  end
end

def prepare_drop
  @input_taxon = Taxon.make!( rank: Taxon::FAMILY )
  @drop = TaxonDrop.make
  @drop.add_input_taxon(@input_taxon)
  @drop.save!  
end
