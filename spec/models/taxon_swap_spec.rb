require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonSwap, "commit" do
  before(:each) do
    prepare_swap
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

  # it "should generate updates for observers of the old taxon"
  # it "should generate updates for identifiers of the old taxon"
  # it "should generate updates for listers of the old taxon"
  it "should queue a job to commit records" do
    Delayed::Job.delete_all
    @swap.commit
    Delayed::Job.all.select{|j| j.handler =~ /commit_records/m}.should_not be_blank
  end

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

describe TaxonSwap, "commit_records" do
  before(:each) { prepare_swap }

  it "should update records" do
    obs = Observation.make!(:taxon => @input_taxon)
    @swap.commit_records
    obs.reload
    obs.taxon.should eq(@output_taxon)
  end

  it "should generate updates for people who don't want automation" do
    u = User.make!(:prefers_automatic_taxonomic_changes => false)
    u.prefers_automatic_taxonomic_changes?.should_not be_true
    o = Observation.make!(:taxon => @input_taxon, :user => u)
    lambda {
      @swap.commit_records
    }.should change(Update, :count).by(1)
  end

  it "should not update records for people who don't want automation" do
    u = User.make!(:prefers_automatic_taxonomic_changes => false)
    u.prefers_automatic_taxonomic_changes?.should_not be_true
    o = Observation.make!(:taxon => @input_taxon, :user => u)
    @swap.commit_records
    o.reload
    o.taxon.should_not eq(@output_taxon)
  end

  it "should not generate more than one update per user" do
    u = User.make!(:prefers_automatic_taxonomic_changes => false)
    u.prefers_automatic_taxonomic_changes?.should_not be_true
    2.times do
      o = Observation.make!(:taxon => @input_taxon, :user => u)
    end
    lambda {
      @swap.commit_records
    }.should change(Update, :count).by(1)
  end
end

def prepare_swap
  @input_taxon = Taxon.make!
  @output_taxon = Taxon.make!
  @swap = TaxonSwap.make
  @swap.add_input_taxon(@input_taxon)
  @swap.add_output_taxon(@output_taxon)
  @swap.save!
end
