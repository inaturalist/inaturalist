require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonSwap, "creation" do
  before(:each) { enable_elastic_indexing(Observation, Update) }
  after(:each) { disable_elastic_indexing(Observation, Update) }
  it "should not allow swaps without inputs" do
    output_taxon = Taxon.make!
    swap = TaxonSwap.make
    swap.add_output_taxon(output_taxon)
    expect(swap.input_taxa).to be_blank
    expect(swap).not_to be_valid
  end

  it "should not allow swaps without outputs" do
    input_taxon = Taxon.make!
    swap = TaxonSwap.make
    swap.add_input_taxon(input_taxon)
    expect(swap).not_to be_valid
  end
end

describe TaxonSwap, "destruction" do
  before(:each) do
    enable_elastic_indexing(Observation, Update)
    prepare_swap
  end
  after(:each) { disable_elastic_indexing(Observation, Update) }

  it "should destroy updates" do
    Observation.make!(:taxon => @input_taxon)
    without_delay { @swap.commit }
    expect(@swap.updates.to_a).not_to be_blank
    old_id = @swap.id
    @swap.destroy
    expect(Update.where(:resource_type => "TaxonSwap", :resource_id => old_id).to_a).to be_blank
  end

  it "should destroy subscriptions" do
    s = Subscription.make!(:resource => @swap)
    @swap.destroy
    dead_s = Subscription.find_by_id(s.id)
    expect(dead_s).to be_blank
  end
end

describe TaxonSwap, "commit" do
  before(:each) do
    prepare_swap
  end

  it "should duplicate conservation status" do
    @input_taxon.update_attribute(:conservation_status, Taxon::IUCN_ENDANGERED)
    expect(@output_taxon.conservation_status).to be_blank
    @swap.commit
    expect(@output_taxon.conservation_status).to eq(Taxon::IUCN_ENDANGERED)
  end

  it "should duplicate conservation statuses" do
    cs = ConservationStatus.make!(:taxon => @input_taxon)
    expect(@output_taxon.conservation_statuses).to be_blank
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.conservation_statuses.first.status).to eq(cs.status)
    expect(@output_taxon.conservation_statuses.first.authority).to eq(cs.authority)
  end

  it "should duplicate taxon names" do
    name = "Bunny foo foo"
    @input_taxon.taxon_names.create(:name => name, :lexicon => TaxonName::ENGLISH)
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name}).to be_blank
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name}).not_to be_blank
  end

  it "should mark the duplicate of the input taxon's sciname as invalid" do
    @swap.commit
    @output_taxon.reload
    tn = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon.name}
    expect(tn).not_to be_blank
    expect(tn).not_to be_is_valid
  end

  it "should duplicate taxon range if one isn't already set" do
    tr = TaxonRange.make!(:taxon => @input_taxon)
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_ranges).not_to be_blank
  end

  it "should not duplicate taxon range if one is already set" do
    tr1 = TaxonRange.make!(:taxon => @input_taxon)
    tr2 = TaxonRange.make!(:taxon => @output_taxon)
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_ranges.count).to eq(1)
  end

  it "should duplicate colors" do
    color = Color.create(:value => "red")
    @input_taxon.colors << color
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.colors.count).to eq(1)
  end

  # it "should generate updates for observers of the old taxon"
  # it "should generate updates for identifiers of the old taxon"
  # it "should generate updates for listers of the old taxon"
  it "should queue a job to commit records" do
    Delayed::Job.delete_all
    @swap.commit
    expect(Delayed::Job.all.select{|j| j.handler =~ /commit_records/m}).not_to be_blank
  end

  it "should mark the input taxon as inactive" do
    @swap.commit
    @input_taxon.reload
    expect(@input_taxon).not_to be_is_active
  end

  it "should mark the output taxon as active" do
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon).to be_is_active
  end
end

describe TaxonSwap, "commit_records" do
  before(:each) do
    prepare_swap
    enable_elastic_indexing(Observation, Taxon, Update, Place)
  end
  after(:each) { disable_elastic_indexing(Observation, Taxon, Update, Place) }

  it "should update records" do
    obs = Observation.make!(:taxon => @input_taxon)
    @swap.commit_records
    obs.reload
    expect(obs.taxon).to eq(@output_taxon)
  end

  it "should generate updates for people who DO want automation" do
    u = User.make!(:prefers_automatic_taxonomic_changes => true)
    expect(u.prefers_automatic_taxonomic_changes?).to be true
    o = Observation.make!(:taxon => @input_taxon, :user => u)
    expect {
      @swap.commit_records
    }.to change(Update, :count).by(1)
  end

  it "should generate updates for people who don't want automation" do
    u = User.make!(:prefers_automatic_taxonomic_changes => false)
    expect(u.prefers_automatic_taxonomic_changes?).not_to be true
    o = Observation.make!(:taxon => @input_taxon, :user => u)
    expect {
      @swap.commit_records
    }.to change(Update, :count).by(1)
  end

  it "should not update records for people who don't want automation" do
    u = User.make!(:prefers_automatic_taxonomic_changes => false)
    expect(u.prefers_automatic_taxonomic_changes?).not_to be true
    o = Observation.make!(:taxon => @input_taxon, :user => u)
    @swap.commit_records
    o.reload
    expect(o.taxon).not_to eq(@output_taxon)
  end

  it "should not generate more than one update per user" do
    u = User.make!(:prefers_automatic_taxonomic_changes => false)
    expect(u.prefers_automatic_taxonomic_changes?).not_to be true
    2.times do
      o = Observation.make!(:taxon => @input_taxon, :user => u)
    end
    expect {
      @swap.commit_records
    }.to change(Update, :count).by(1)
  end

  it "should should update check listed taxa" do
    tr = TaxonRange.make!(:taxon => @input_taxon)
    cl = CheckList.make!
    lt = ListedTaxon.make!(:list => cl, :taxon => @input_taxon, :taxon_range => tr)
    without_delay{ @swap.commit_records }
    # Delayed::Worker.new.work_off
    lt.reload
    expect(lt.taxon).to eq(@output_taxon)
  end

  it "should add new identifications" do
    ident = Identification.make!(:taxon => @input_taxon)
    @swap.commit_records
    ident.reload
    expect(ident).not_to be_current
    new_ident = ident.observation.identifications.by(ident.user).order("id asc").last
    expect(new_ident).not_to eq(ident)
    expect(new_ident.taxon).to eq(@output_taxon)
  end

  it "should add new identifications with taxon change set" do
    ident = Identification.make!(:taxon => @input_taxon)
    @swap.commit_records
    new_ident = ident.observation.identifications.by(ident.user).order("id asc").last
    expect(new_ident.taxon_change).to eq(@swap)
  end

  it "should add new identifications for owner with taxon change set" do
    obs = Observation.make!(:taxon => @input_taxon)
    ident = Identification.make!(:taxon => @input_taxon, :observation => obs)
    @swap.commit_records
    obs.reload
    new_ident = obs.owners_identification
    expect(new_ident.taxon_change).to eq(@swap)
  end

  it "should not update existing identifications" do
    ident = Identification.make!(:taxon => @input_taxon)
    @swap.commit_records
    ident.reload
    expect(ident).not_to be_current
    expect(ident.taxon).not_to eq(@output_taxon)
  end

  it "should only add one new identification per observer" do
    obs = Observation.make!(:taxon => @input_taxon)
    ident = obs.owners_identification
    @swap.commit_records
    ident.reload
    expect(ident.observation.identifications.by(ident.user).of(@output_taxon).count).to eq(1)
  end

  it "should not queue job to generate updates for new identifications" do
    obs = Observation.make!(:taxon => @input_taxon)
    Delayed::Job.delete_all
    stamp = Time.now
    @swap.commit_records
    expect( Delayed::Job.where("created_at >= ?", stamp).detect{|j| 
      j.handler =~ /notify_subscribers_of/ && j.handler =~ /Identification/
    } ).to be_blank
  end

  it "should re-evalute community taxa" do
    o = Observation.make!
    i1 = Identification.make!(:taxon => @input_taxon, :observation => o)
    i2 = Identification.make!(:taxon => @input_taxon, :observation => o)
    expect(o.community_taxon).to eq @input_taxon
    @swap.commit_records
    o.reload
    expect(o.community_taxon).to eq @output_taxon
  end

  it "should set counter caches correctly" do
    without_delay do
      3.times { Observation.make!(:taxon => @input_taxon) }
    end
    @input_taxon.reload
    expect(@input_taxon.observations_count).to eq(3)
    expect(@output_taxon.observations_count).to eq(0)
    @swap.commit_records
    @input_taxon.reload
    @output_taxon.reload
    expect(@input_taxon.observations_count).to eq(0)
    expect(@output_taxon.observations_count).to eq(3)
  end

  it "should be copacetic with content with a blank user" do
    l = CheckList.make!
    l.update_attributes(:user => nil)
    expect(l.user).to be_blank
    lt = ListedTaxon.make!(:taxon => @input_taxon, :list => l)
    lt.update_attributes(:user => nil)
    expect(lt.user).to be_blank
    without_delay { @swap.commit_records }
    lt.reload
    @output_taxon.reload
    expect(lt.taxon_id).to eq(@output_taxon.id)
  end

  it "should not choke on non-primary checklisted taxa without primaries" do
    l = CheckList.make!
    lt = ListedTaxon.make!(:list => l, :primary_listing => false, :taxon => @input_taxon)
    lt.update_attribute(:primary_listing, false)
    expect(lt).not_to be_primary_listing
    expect(lt.primary_listing).to be_blank
    without_delay { 
      expect {
        @swap.commit_records
      }.not_to raise_error
    }
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
