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
    expect(@output_taxon.conservation_status).to be_blank
    @merge.commit
    expect(@output_taxon.conservation_status).to be_blank
  end

  it "should duplicate taxon names" do
    name1 = "Tyra"
    name2 = "Landry"
    TaxonName.make!(:name => name1, :lexicon => TaxonName::ENGLISH, :taxon => @input_taxon1)
    TaxonName.make!(:name => name2, :lexicon => TaxonName::ENGLISH, :taxon => @input_taxon2)
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name1}).not_to be_blank
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name2}).not_to be_blank
  end

  it "should mark the duplicate of the input taxon's sciname as invalid" do
    @merge.commit
    @output_taxon.reload
    tn1 = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon1.name}
    tn2 = @output_taxon.taxon_names.detect{|tn| tn.name == @input_taxon2.name}
    expect(tn1).not_to be_blank
    expect(tn1).not_to be_is_valid
    expect(tn2).not_to be_blank
    expect(tn2).not_to be_is_valid
  end

  it "should not duplicate taxon range if one is already set" do
    tr1 = TaxonRange.make!(:taxon => @input_taxon1)
    tr2 = TaxonRange.make!(:taxon => @output_taxon)
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_ranges.count).to eq(1)
  end

  it "should duplicate colors" do
    color = Color.create(:value => "red")
    @input_taxon1.colors << color
    @input_taxon2.colors << color
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.colors.count).to eq(1)
  end

  it "should not duplicate conservation_statuses" do
    cs1 = ConservationStatus.make!(:taxon => @input_taxon1, :authority => "foo")
    cs2 = ConservationStatus.make!(:taxon => @input_taxon2, :authority => "bar")
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon.conservation_statuses).to be_blank
  end

  it "should generate updates for observers of the old taxon"
  it "should generate updates for identifiers of the old taxon"
  it "should generate updates for listers of the old taxon"

  it "should mark the input taxon as inactive" do
    @merge.commit
    @input_taxon1.reload
    expect(@input_taxon1).not_to be_is_active
    @input_taxon2.reload
    expect(@input_taxon2).not_to be_is_active
  end

  it "should mark the output taxon as active" do
    @merge.commit
    @output_taxon.reload
    expect(@output_taxon).to be_is_active
  end

  it "should move children from the input to the output taxon" do
    child1 = Taxon.make!( parent: @input_taxon1 )
    descendant1 = Taxon.make!( parent: child1 )
    child2 = Taxon.make!( parent: @input_taxon2 )
    descendant2 = Taxon.make!( parent: child2 )
    without_delay { @merge.commit }
    child1.reload
    child2.reload
    descendant1.reload
    descendant2.reload
    expect( child1.parent ).to eq @output_taxon
    expect( descendant1.ancestor_ids ).to include @output_taxon.id
    expect( child2.parent ).to eq @output_taxon
    expect( descendant2.ancestor_ids ).to include @output_taxon.id
  end

  describe "should make swaps for all children when swapping a" do
    it "genus" do
      @input_taxon1.update_attributes( rank: Taxon::GENUS, name: "Hyla", rank_level: Taxon::GENUS_LEVEL )
      @input_taxon2.update_attributes( rank: Taxon::GENUS, name: "Rana", rank_level: Taxon::GENUS_LEVEL )
      @output_taxon.update_attributes( rank: Taxon::GENUS, name: "Pseudacris", rank_level: Taxon::GENUS_LEVEL )
      child1 = Taxon.make!( parent: @input_taxon1, rank: Taxon::SPECIES, name: "Hyla regilla", rank_level: Taxon::SPECIES_LEVEL )
      child2 = Taxon.make!( parent: @input_taxon2, rank: Taxon::SPECIES, name: "Rana clamitans", rank_level: Taxon::SPECIES_LEVEL )
      [@input_taxon1, @output_taxon, child1, child2].each(&:reload)
      without_delay { @merge.commit }
      [@input_taxon1, @output_taxon, child1, child2].each(&:reload)
      expect( child1.parent ).to eq @input_taxon1
      expect( child2.parent ).to eq @input_taxon2
      child_swap1 = child1.taxon_change_taxa.first.taxon_change
      child_swap2 = child2.taxon_change_taxa.first.taxon_change
      expect( child_swap1 ).not_to be_blank
      expect( child_swap2 ).not_to be_blank
      expect( child_swap1.output_taxon.name ).to eq "Pseudacris regilla"
      expect( child_swap2.output_taxon.name ).to eq "Pseudacris clamitans"
      expect( child_swap1.output_taxon.parent ).to eq @output_taxon
      expect( child_swap2.output_taxon.parent ).to eq @output_taxon
    end
    it "species" do
      @input_taxon1.update_attributes( rank: Taxon::GENUS, name: "Hyla regilla", rank_level: Taxon::GENUS_LEVEL )
      @input_taxon2.update_attributes( rank: Taxon::GENUS, name: "Rana clamitans", rank_level: Taxon::GENUS_LEVEL )
      @output_taxon.update_attributes( rank: Taxon::GENUS, name: "Pseudacris regilla", rank_level: Taxon::GENUS_LEVEL )
      child1 = Taxon.make!( parent: @input_taxon1, rank: Taxon::SPECIES, name: "Hyla regilla foo", rank_level: Taxon::SPECIES_LEVEL )
      child2 = Taxon.make!( parent: @input_taxon2, rank: Taxon::SPECIES, name: "Rana clamitans foo", rank_level: Taxon::SPECIES_LEVEL )
      [@input_taxon1, @output_taxon, child1, child2].each(&:reload)
      without_delay { @merge.commit }
      [@input_taxon1, @output_taxon, child1, child2].each(&:reload)
      expect( child1.parent ).to eq @input_taxon1
      expect( child2.parent ).to eq @input_taxon2
      child_swap1 = child1.taxon_change_taxa.first.taxon_change
      child_swap2 = child2.taxon_change_taxa.first.taxon_change
      expect( child_swap1 ).not_to be_blank
      expect( child_swap2 ).not_to be_blank
      expect( child_swap1.output_taxon.name ).to eq "Pseudacris regilla foo"
      expect( child_swap2.output_taxon.name ).to eq "Pseudacris regilla foo"
      expect( child_swap1.output_taxon.parent ).to eq @output_taxon
      expect( child_swap2.output_taxon.parent ).to eq @output_taxon
      expect( child_swap2.output_taxon ).to eq child_swap1.output_taxon
    end
  end
end

describe TaxonMerge, "commit_records" do
  before(:each) do
    setup_taxon_merge
  end
  it "should add new identifications" do
    ident = Identification.make!( taxon: @input_taxon1 )
    @merge.commit_records
    ident.reload
    expect(ident).not_to be_current
    new_ident = ident.observation.identifications.by(ident.user).order("id asc").last
    expect(new_ident).not_to eq(ident)
    expect(new_ident.taxon).to eq(@output_taxon)
  end

  it "should not add multiple identifications" do
    ident = Identification.make!( taxon: @input_taxon1, observation: Observation.make!(taxon: @input_taxon1) )
    2.times do
      Identification.make!( taxon: @input_taxon1, observation: ident.observation )
    end
    expect( ident.observation.identifications.by( ident.observation.user ).count ).to eq 1
    @merge.commit_records
    ident.reload
    expect( ident.observation.identifications.by( ident.observation.user ).count ).to eq 2
  end
  it "should not add multiple identifications for the observer when run twice and the obs is still associated with the old taxon" do
    o = make_research_grade_observation( taxon: @input_taxon1 )
    expect( o.identifications.by( o.user ).count ).to eq 1
    @merge.commit_records
    5.times do
      Identification.make!( observation: o, taxon: @input_taxon1 )
    end
    o.reload
    expect( o.taxon ).to eq @input_taxon1
    @merge.commit_records
    o.reload
    expect( o.identifications.by( o.user ).count ).to eq 2
  end
end
