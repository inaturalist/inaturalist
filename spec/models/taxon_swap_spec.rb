require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonSwap, "commit" do
  before(:each) do
    @input_taxon = Taxon.make!
    @output_taxon = Taxon.make!
    @swap = TaxonSwap.make
    @swap.add_input_taxon(@input_taxon)
    @swap.add_output_taxon(@output_taxon)
    @swap.save!
  end

  it "should duplicate conservation status" do
    @input_taxon.update_attribute(:conservation_status, Taxon::IUCN_ENDANGERED)
    @output_taxon.conservation_status.should be_blank
    @swap.commit
    @output_taxon.conservation_status.should eq(Taxon::IUCN_ENDANGERED)
  end

  it "should duplicate taxon names" do
    name = "Bunny foo foo"
    @input_taxon.taxon_names.create(:name => name, :lexicon => TaxonName::ENGLISH)
    @output_taxon.taxon_names.detect{|tn| tn.name == name}.should be_blank
    @swap.commit
    @output_taxon.reload
    @output_taxon.taxon_names.detect{|tn| tn.name == name}.should_not be_blank
  end

  it "should mark the duplicate of the input taxon's sciname as invalid" do
    @swap.commit
    @output_taxon.reload
    tn = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon.name}
    tn.should_not be_blank
    tn.should_not be_is_valid
  end

  it "should duplicate taxon range if one isn't already set" do
    tr = TaxonRange.make!(:taxon => @input_taxon)
    @swap.commit
    @output_taxon.reload
    @output_taxon.taxon_ranges.should_not be_blank
  end

  it "should not duplicate taxon range if one is already set" do
    tr1 = TaxonRange.make!(:taxon => @input_taxon)
    tr2 = TaxonRange.make!(:taxon => @output_taxon)
    @swap.commit
    @output_taxon.reload
    @output_taxon.taxon_ranges.count.should eq(1)
  end

  it "should duplicate colors" do
    color = Color.create(:value => "red")
    @input_taxon.colors << color
    @swap.commit
    @output_taxon.reload
    @output_taxon.colors.count.should eq(1)
  end

  it "should generate updates for observers of the old taxon"
  it "should generate updates for identifiers of the old taxon"
  it "should generate updates for listers of the old taxon"
  it "should mark the input taxon as inactive" do
    @swap.commit
    @input_taxon.reload
    @input_taxon.should_not be_is_active
  end

  it "should mark the output taxon as active" do
    @swap.commit
    @output_taxon.reload
    @output_taxon.should be_is_active
  end
end
