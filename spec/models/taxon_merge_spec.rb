require File.dirname(__FILE__) + '/../spec_helper.rb'

def setup_taxon_merge
  @input_ancestor = Taxon.make!( rank: Taxon::GENUS )
  @input_taxon1 = Taxon.make!( rank: Taxon::SPECIES, parent: @input_ancestor )
  @input_taxon2 = Taxon.make!( rank: Taxon::SPECIES, parent: @input_ancestor )
  @input_taxon3 = Taxon.make!( rank: Taxon::SPECIES, parent: @input_ancestor )
  @output_taxon = Taxon.make!( rank: Taxon::SPECIES )
  @merge = TaxonMerge.make
  @merge.add_input_taxon( @input_taxon1 )
  @merge.add_input_taxon( @input_taxon2 )
  @merge.add_input_taxon( @input_taxon3 )
  @merge.add_output_taxon( @output_taxon )
  @merge.save!
  @merge.reload
end

def clean_taxon_merge
  @merge.destroy
  @input_taxon1.destroy
  @input_taxon2.destroy
  @input_taxon3.destroy
  @output_taxon.destroy
  @input_ancestor.destroy
end

describe "create" do
  it "should not allow a single input taxon" do
    setup_taxon_merge
    tc = TaxonMerge.make
    tc.add_input_taxon( Taxon.make! )
    tc.add_output_taxon( Taxon.make! )
    expect( tc ).not_to be_valid
  end
end

describe TaxonMerge, "commit" do
  before(:each) do
    setup_taxon_merge
    @merge.committer = @merge.user
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

  describe "for taxa with children" do
    elastic_models( Observation, Identification )
    after(:each) { clean_taxon_merge }

    before(:each) do
      @merge.update_attributes( move_children: true )
    end

    it "should move children from the input to the output taxon" do
      clean_taxon_merge
      setup_taxon_merge
      @merge.committer = @merge.user
      @merge.update_attributes( move_children: true )
      @input_ancestor.update_attributes( rank: Taxon::ORDER, rank_level: Taxon::ORDER_LEVEL )
      @input_taxon1.update_attributes( rank: Taxon::SUPERFAMILY, rank_level: Taxon::SUPERFAMILY_LEVEL )
      @input_taxon2.update_attributes( rank: Taxon::SUPERFAMILY, rank_level: Taxon::SUPERFAMILY_LEVEL )
      @output_taxon.update_attributes( rank: Taxon::SUPERFAMILY, rank_level: Taxon::SUPERFAMILY_LEVEL )
      child1 = Taxon.make!( parent: @input_taxon1, rank: Taxon::FAMILY )
      descendant1 = Taxon.make!( parent: child1, rank: Taxon::GENUS )
      child2 = Taxon.make!( parent: @input_taxon2, rank: Taxon::FAMILY )
      descendant2 = Taxon.make!( parent: child2, rank: Taxon::GENUS )
      @merge.reload
      @merge.committer = @merge.user
      expect( @merge ).to be_valid
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

    describe "should make swaps for all children when merging a" do
      it "genus" do
        @input_ancestor.update_attributes( rank: Taxon::FAMILY, rank_level: Taxon::FAMILY_LEVEL )
        @input_taxon1.update_attributes( rank: Taxon::GENUS, name: "Hyla" )
        @input_taxon2.update_attributes( rank: Taxon::GENUS, name: "Rana" )
        @output_taxon.update_attributes( rank: Taxon::GENUS, name: "Pseudacris" )
        child1 = Taxon.make!( parent: @input_taxon1, rank: Taxon::SPECIES, name: "Hyla regilla" )
        child2 = Taxon.make!( parent: @input_taxon2, rank: Taxon::SPECIES, name: "Rana clamitans" )
        [@merge, @input_taxon1, @output_taxon, child1, child2].each(&:reload)
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
        @input_taxon1.update_attributes( rank: Taxon::SPECIES, name: "Hyla regilla" )
        @input_taxon2.update_attributes( rank: Taxon::SPECIES, name: "Rana clamitans" )
        @output_taxon.update_attributes( rank: Taxon::SPECIES, name: "Pseudacris regilla" )
        child1 = Taxon.make!( parent: @input_taxon1, rank: Taxon::SUBSPECIES, name: "Hyla regilla foo", rank_level: Taxon::SPECIES_LEVEL )
        child2 = Taxon.make!( parent: @input_taxon2, rank: Taxon::SUBSPECIES, name: "Rana clamitans foo", rank_level: Taxon::SPECIES_LEVEL )
        [@merge, @input_taxon1, @output_taxon, child1, child2].each(&:reload)
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

    it "should not make swaps for children if they are included in the merge" do
      @input_taxon1.update_attributes( rank: Taxon::SPECIES, name: "Hyla regilla" )
      @input_taxon2.update_attributes( rank: Taxon::SUBSPECIES, name: "Hyla regilla regilla", parent: @input_taxon1 )
      @output_taxon.update_attributes( rank: Taxon::SPECIES, name: "Pseudacris regilla" )
      [@input_taxon1, @output_taxon].each(&:reload)
      without_delay { @merge.commit }
      [@input_taxon1, @input_taxon2, @output_taxon].each(&:reload)
      expect( @input_taxon2.parent ).to eq @input_taxon1
      expect( @input_taxon2.taxon_change_taxa.size ).to eq 1
      expect( @input_taxon2.taxon_change_taxa.first.taxon_change ).to eq @merge
    end

    it "should move a child if a swap would make a new taxon with the same name" do
      @input_ancestor.update_attributes( rank: Taxon::FAMILY, name: "Hylidae" )
      @input_taxon1.update_attributes( rank: Taxon::GENUS, name: "Acris" )
      @input_taxon2.update_attributes( rank: Taxon::GENUS, name: "Pseudacris" )
      @input_taxon3.update_attributes( rank: Taxon::GENUS, name: "Hyla" )
      @output_taxon.update_attributes( rank: Taxon::GENUS, name: "Acris", is_active: false )
      child = Taxon.make!( parent: @input_taxon1, rank: Taxon::SPECIES, name: "Acris blanchardii" )
      @merge.reload
      @merge.commit
      Delayed::Worker.new.work_off
      child.reload
      @output_taxon.reload
      expect( child.parent ).to eq @output_taxon
      expect( child.taxon_changes.count ).to eq 0
      expect( child.taxon_change_taxa.count ).to eq 0
    end
  end
end

describe TaxonMerge, "commit_records" do
  before(:each) do
    setup_taxon_merge
  end
  elastic_models( Observation, Identification )
  it "should add new identifications for all inputs" do
    ident1 = Identification.make!( taxon: @input_taxon1 )
    ident2 = Identification.make!( taxon: @input_taxon2 )
    ident3 = Identification.make!( taxon: @input_taxon3 )
    @merge.commit_records
    ident1.reload
    ident2.reload
    ident3.reload
    expect( ident1 ).not_to be_current
    expect( ident2 ).not_to be_current
    expect( ident3 ).not_to be_current
    new_ident1 = ident1.observation.identifications.by( ident1.user ).order( "id asc" ).last
    new_ident2 = ident2.observation.identifications.by( ident2.user ).order( "id asc" ).last
    new_ident3 = ident3.observation.identifications.by( ident3.user ).order( "id asc" ).last
    expect( new_ident1 ).not_to eq( ident1 )
    expect( new_ident1.taxon ).to eq( @output_taxon )
    expect( new_ident2 ).not_to eq( ident2 )
    expect( new_ident2.taxon ).to eq( @output_taxon )
    expect( new_ident3 ).not_to eq( ident3 )
    expect( new_ident3.taxon ).to eq( @output_taxon )
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

  it "should set a current identification's previous_observation_taxon if it is the input" do
    o = Observation.make!( taxon: @input_taxon1 )
    g = Taxon.make!( rank: Taxon::GENUS )
    s = Taxon.make!( rank: Taxon::SPECIES, parent: g )
    ident = Identification.make!( observation: o, taxon: s )
    expect( ident.previous_observation_taxon ).to eq @input_taxon1
    @merge.commit_records
    ident.reload
    expect( ident.previous_observation_taxon ).to eq @output_taxon
  end
  
  it "should replace an inactive previous_observation_taxon with it's current active synonym" do
    other_swap = TaxonSwap.make
    other_swap.add_input_taxon( Taxon.make!( :species, is_active: false, name: "OtherInputSpecies" ) )
    other_swap.add_output_taxon( Taxon.make!( :species, is_active: false, name: "OtherOutputSpecies" ) )
    without_delay do
      other_swap.committer = make_admin
      other_swap.commit
      other_swap.commit_records
    end
    g = Taxon.make!( rank: Taxon::GENUS )
    s = Taxon.make!( rank: Taxon::SPECIES, parent: g )
    o = Observation.make!( taxon: s )
    ident = Identification.make!( observation: o, taxon: @input_taxon1 )
    ident.update_attributes(
      skip_set_previous_observation_taxon: true,
      previous_observation_taxon: other_swap.input_taxon
    )
    expect( ident ).to be_disagreement
    expect( ident.previous_observation_taxon ).to eq other_swap.input_taxon
    expect( ident.previous_observation_taxon ).not_to be_is_active
    @merge.commit_records
    o.reload
    new_ident = o.identifications.current.where( user_id: ident.user_id ).first
    expect( new_ident.previous_observation_taxon ).to eq other_swap.output_taxon
  end
  
  it "should commit a taxon merge with all input taxon active child rank levels finer than the output taxon rank level" do
    child = Taxon.make!( is_active: true, parent: @input_taxon1, rank: Taxon::SUBSPECIES )
    @merge.reload
    @merge.committer = @merge.user
    @merge.move_children = true
    expect {
      @merge.commit
    }.not_to raise_error # TaxonChange::RankLevelError
  end
  
  it "should not commit a taxon merge without all input taxon active child rank levels finer than the output taxon rank level" do
    @output_taxon.update_attributes(
     rank: Taxon::SUBSPECIES,
     rank_level: Taxon::SUBSPECIES_LEVEL
    )
    child = Taxon.make!( is_active: true, parent: @input_taxon1, rank: Taxon::SUBSPECIES )
    @merge.reload
    @merge.move_children = true
    @merge.committer = @merge.user
    expect {
      @merge.commit
    }.to raise_error TaxonChange::RankLevelError
  end
  
  it "should commit a taxon merge with childless input taxon rank level coarser than the output taxon rank level" do
    @output_taxon.update_attribute(
     :rank, Taxon::SUBSPECIES
    )
    child = Taxon.make!( is_active: true, parent: @input_taxon1, rank: Taxon::SUBSPECIES )
    @merge.move_children = true
    @merge.committer = @merge.user
    expect {
      @merge.commit
    }.not_to raise_error # TaxonChange::RankLevelError
  end
  
  it "should raise an error if input taxon has active children that aren't involved in the merge" do
    child = Taxon.make!( rank: Taxon::SUBSPECIES, parent: @input_taxon1 )
    @merge.committer = @merge.user
    expect {
      @merge.commit
    }.to raise_error TaxonChange::ActiveChildrenError
  end
  
  it "should not raise an error if input taxon has no active children that aren't involved in the merge" do
    child = Taxon.make!( rank: Taxon::SUBSPECIES, parent: @input_taxon1 )
    @merge.add_input_taxon( child )
    @merge.save
    @merge.reload
    @merge.committer = @merge.user
    expect {
      @merge.commit
    }.not_to raise_error # TaxonChange::ActiveChildrenError
  end

  it "should re-evalute community taxa" do
    o = Observation.make!
    i1 = Identification.make!( taxon: @input_taxon1, observation: o )
    i2 = Identification.make!( taxon: @input_taxon1, observation: o )
    expect( o.community_taxon ).to eq @input_taxon1
    @merge.commit_records
    o.reload
    expect( o.community_taxon ).to eq @output_taxon
  end
end
