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

  it "should generate updates for people who DO want automation" do
    u = User.make!(:prefers_automatic_taxonomic_changes => true)
    u.prefers_automatic_taxonomic_changes?.should be_true
    o = Observation.make!(:taxon => @input_taxon, :user => u)
    lambda {
      @swap.commit_records
    }.should change(Update, :count).by(1)
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

  it "should should update check listed taxa" do
    tr = TaxonRange.make!(:taxon => @input_taxon)
    cl = CheckList.make!
    lt = ListedTaxon.make!(:list => cl, :taxon => @input_taxon, :taxon_range => tr)
    @swap.commit_records
    lt.reload
    lt.taxon.should eq(@output_taxon)
  end

  it "should add new identifications" do
    ident = Identification.make!(:taxon => @input_taxon)
    @swap.commit_records
    ident.reload
    ident.should_not be_current
    new_ident = ident.observation.identifications.by(ident.user).order("id asc").last
    new_ident.should_not eq(ident)
    new_ident.taxon.should eq(@output_taxon)
  end

  it "should add new identifications with taxon change set" do
    ident = Identification.make!(:taxon => @input_taxon)
    @swap.commit_records
    new_ident = ident.observation.identifications.by(ident.user).order("id asc").last
    new_ident.taxon_change.should eq(@swap)
  end

  it "should add new identifications for owner with taxon change set" do
    obs = Observation.make!(:taxon => @input_taxon)
    ident = Identification.make!(:taxon => @input_taxon, :observation => obs)
    @swap.commit_records
    obs.reload
    new_ident = obs.owners_identification
    new_ident.taxon_change.should eq(@swap)
  end

  it "should not update existing identifications" do
    ident = Identification.make!(:taxon => @input_taxon)
    @swap.commit_records
    ident.reload
    ident.should_not be_current
    ident.taxon.should_not eq(@output_taxon)
  end

  it "should only add one new identification per observer" do
    obs = Observation.make!(:taxon => @input_taxon)
    ident = obs.owners_identification
    @swap.commit_records
    ident.reload
    ident.observation.identifications.by(ident.user).of(@output_taxon).count.should eq(1)
  end

  it "should not queue job to generate updates for new identifications" do
    obs = Observation.make!(:taxon => @input_taxon)
    Delayed::Job.delete_all
    stamp = Time.now
    @swap.commit_records
    Delayed::Job.where("created_at >= ?", stamp).detect{|j| j.handler =~ /notify_subscribers_of/}.should be_blank
  end

  it "should set counter caches correctly" do
    3.times { Observation.make!(:taxon => @input_taxon) }
    @input_taxon.reload
    @input_taxon.observations_count.should eq(3)
    @output_taxon.observations_count.should eq(0)
    @swap.commit_records
    @input_taxon.reload
    @output_taxon.reload
    @input_taxon.observations_count.should eq(0)
    @output_taxon.observations_count.should eq(3)
  end

  it "should be copacetic with content with a blank user" do
    l = CheckList.make!
    l.update_attributes(:user => nil)
    l.user.should be_blank
    lt = ListedTaxon.make!(:taxon => @input_taxon, :list => l)
    lt.update_attributes(:user => nil)
    lt.user.should be_blank
    @swap.commit_records
    lt.reload
    @output_taxon.reload
    lt.taxon_id.should eq(@output_taxon.id)
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
