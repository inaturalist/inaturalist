require File.dirname(__FILE__) + '/../spec_helper.rb'

def setup_taxon_merge
  @input_taxon1 = Taxon.make!
  @input_taxon2 = Taxon.make!
  @output_taxon = Taxon.make!
  @merge = TaxonMerge.make
  @merge.add_input_taxon(@input_taxon1)
  @merge.add_input_taxon(@input_taxon2)
  @merge.add_output_taxon(@output_taxon)
  @merge.save!
end

describe TaxonMerge, "commit" do
  before(:each) do
    setup_taxon_merge
  end

  it "should not duplicate conservation status" do
    @input_taxon1.update_attribute(:conservation_status, Taxon::IUCN_ENDANGERED)
    @output_taxon.conservation_status.should be_blank
    @merge.commit
    @output_taxon.conservation_status.should be_blank
  end

  it "should duplicate taxon names" do
    name1 = "Tyra"
    name2 = "Landry"
    TaxonName.make!(:name => name1, :lexicon => TaxonName::ENGLISH, :taxon => @input_taxon1)
    TaxonName.make!(:name => name2, :lexicon => TaxonName::ENGLISH, :taxon => @input_taxon2)
    @merge.commit
    @output_taxon.reload
    @output_taxon.taxon_names.detect{|tn| tn.name == name1}.should_not be_blank
    @output_taxon.taxon_names.detect{|tn| tn.name == name2}.should_not be_blank
  end

  it "should mark the duplicate of the input taxon's sciname as invalid" do
    @merge.commit
    @output_taxon.reload
    tn1 = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon1.name}
    tn2 = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon2.name}
    tn1.should_not be_blank
    tn1.should_not be_is_valid
    tn2.should_not be_blank
    tn2.should_not be_is_valid
  end

  # hm, ideally it should merge ranges if all inputs have a range and the output doesn't, right?
  # it "should duplicate taxon range if one isn't already set" do
  #   tr = TaxonRange.make!(:taxon => @input_taxon)
  #   @merge.commit
  #   @output_taxon.reload
  #   @output_taxon.taxon_ranges.should_not be_blank
  # end

  it "should not duplicate taxon range if one is already set" do
    tr1 = TaxonRange.make!(:taxon => @input_taxon1)
    tr2 = TaxonRange.make!(:taxon => @output_taxon)
    @merge.commit
    @output_taxon.reload
    @output_taxon.taxon_ranges.count.should eq(1)
  end

  it "should duplicate colors" do
    color = Color.create(:value => "red")
    @input_taxon1.colors << color
    @input_taxon2.colors << color
    @merge.commit
    @output_taxon.reload
    @output_taxon.colors.count.should eq(1)
  end

  it "should not duplicate conservation_statuses" do
    cs1 = ConservationStatus.make!(:taxon => @input_taxon1, :authority => "foo")
    cs2 = ConservationStatus.make!(:taxon => @input_taxon2, :authority => "bar")
    @merge.commit
    @output_taxon.reload
    @output_taxon.conservation_statuses.should be_blank
  end

  it "should generate updates for observers of the old taxon"
  it "should generate updates for identifiers of the old taxon"
  it "should generate updates for listers of the old taxon"

  it "should mark the input taxon as inactive" do
    @merge.commit
    @input_taxon1.reload
    @input_taxon1.should_not be_is_active
    @input_taxon2.reload
    @input_taxon2.should_not be_is_active
  end

  it "should mark the output taxon as active" do
    @merge.commit
    @output_taxon.reload
    @output_taxon.should be_is_active
  end
end

describe TaxonMerge, "commit_records" do
  before(:each) do
    setup_taxon_merge
  end
  it "should add new identifications" do
    ident = Identification.make!(:taxon => @input_taxon1)
    @merge.commit_records
    ident.reload
    expect(ident).not_to be_current
    new_ident = ident.observation.identifications.by(ident.user).order("id asc").last
    expect(new_ident).not_to eq(ident)
    expect(new_ident.taxon).to eq(@output_taxon)
  end
end