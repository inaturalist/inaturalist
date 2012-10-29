require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonDrop, "commit" do
  before(:each) do
    @input_taxon = Taxon.make!
    @drop = TaxonDrop.make
    @drop.add_input_taxon(@input_taxon)
    @drop.save!
  end

  it "should mark input taxon as active" do
    @input_taxon.should be_is_active
    @drop.commit
    @input_taxon.reload
    @input_taxon.should_not be_is_active
  end
end
