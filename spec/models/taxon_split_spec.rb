require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonSplit, "commit" do
  before(:each) { prepare_split }

  it "should generate updates for observers of the old taxon"
  it "should generate updates for identifiers of the old taxon"
  it "should generate updates for listers of the old taxon"

  it "should mark the input taxon as inactive" do
    @split.commit
    @input_taxon.reload
    @input_taxon.should_not be_is_active
  end

  it "should mark the output taxon as active" do
    @split.commit
    @output_taxon1.reload
    @output_taxon1.should be_is_active
    @output_taxon2.reload
    @output_taxon2.should be_is_active
  end
end

describe TaxonSplit, "commit_records" do
  before(:each) { prepare_split }
  it "should not update records" do
    obs = Observation.make!(:taxon => @input_taxon)
    @split.commit_records
    obs.reload
    obs.taxon.should eq(@input_taxon)
  end
end

def prepare_split
  @input_taxon = Taxon.make!
  @output_taxon1 = Taxon.make!
  @output_taxon2 = Taxon.make!
  @split = TaxonSplit.make
  @split.add_input_taxon(@input_taxon)
  @split.add_output_taxon(@output_taxon1)
  @split.add_output_taxon(@output_taxon2)
  @split.save!
end
