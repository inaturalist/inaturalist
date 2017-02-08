require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonSplit, "validation" do
  it "should not allow the same taxon on both sides of the split" do
    old_taxon = Taxon.make!( rank: Taxon::FAMILY )
    new_taxon = Taxon.make!( rank: Taxon::FAMILY )
    tc = TaxonSplit.make
    tc.add_input_taxon(old_taxon)
    tc.add_output_taxon(new_taxon)
    tc.add_output_taxon(old_taxon)
    tc.save
    expect(tc).not_to be_valid
  end

  it "should now allow a split with only one output" do
    tc = TaxonSplit.make
    tc.add_input_taxon( Taxon.make! )
    tc.add_output_taxon( Taxon.make! )
    expect( tc ).not_to be_valid
  end
end

describe TaxonSplit, "commit" do
  before(:each) { prepare_split }

  it "should generate updates for observers of the old taxon"
  it "should generate updates for identifiers of the old taxon"
  it "should generate updates for listers of the old taxon"

  it "should mark the input taxon as inactive" do
    @split.commit
    @input_taxon.reload
    expect(@input_taxon).not_to be_is_active
  end

  it "should mark the output taxon as active" do
    @split.commit
    @output_taxon1.reload
    expect(@output_taxon1).to be_is_active
    @output_taxon2.reload
    expect(@output_taxon2).to be_is_active
  end
end

describe TaxonSplit, "commit_records" do
  before(:each) { prepare_split }
  it "should not update records" do
    obs = Observation.make!(:taxon => @input_taxon)
    @split.commit_records
    obs.reload
    expect(obs.taxon).to eq(@input_taxon)
  end
end

def prepare_split
  @input_taxon = Taxon.make!( rank: Taxon::FAMILY )
  @output_taxon1 = Taxon.make!( rank: Taxon::FAMILY )
  @output_taxon2 = Taxon.make!( rank: Taxon::FAMILY )
  @split = TaxonSplit.make
  @split.add_input_taxon(@input_taxon)
  @split.add_output_taxon(@output_taxon1)
  @split.add_output_taxon(@output_taxon2)
  @split.save!
end
