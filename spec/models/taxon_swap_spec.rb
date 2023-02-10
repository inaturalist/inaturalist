require File.dirname(__FILE__) + '/../spec_helper.rb'

describe TaxonSwap, "creation" do
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  it "should not allow swaps without inputs" do
    output_taxon = Taxon.make!( rank: Taxon::FAMILY )
    swap = TaxonSwap.make
    swap.add_output_taxon(output_taxon)
    expect(swap.input_taxa).to be_blank
    expect(swap).not_to be_valid
  end

  it "should not allow swaps without outputs" do
    input_taxon = Taxon.make!( rank: Taxon::FAMILY )
    swap = TaxonSwap.make
    swap.add_input_taxon(input_taxon)
    expect(swap).not_to be_valid
  end

  it "should now allow identical inputs and outputs" do
    t = Taxon.make!
    swap = TaxonSwap.make
    swap.add_input_taxon( t )
    swap.add_output_taxon( t )
    expect( swap.input_taxon ).to eq swap.output_taxon
    expect( swap ).not_to be_valid
  end

  it "should generate mentions" do
    u = User.make!
    expect( UpdateAction.unviewed_by_user_from_query(u.id, { }) ).to eq false
    tc = without_delay { make_taxon_swap( description: "hey @#{ u.login }" ) }
    expect( UpdateAction.unviewed_by_user_from_query(
      u.id, notifier_type: "TaxonChange", notifier_id: tc.id) ).to eq true
  end

  it "should be possible for a site curator who is not a taxon curator of a complete ancestor of the input taxon" do
    genus = Taxon.make!( rank: Taxon::GENUS )
    tf = TaxonFramework.make!( taxon: genus, rank_level: 5 )
    tc = TaxonCurator.make!( taxon_framework: tf )
    c = make_curator
    input_taxon = Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: tc.user )
    swap = TaxonSwap.make
    swap.add_input_taxon( input_taxon )
    swap.add_output_taxon( Taxon.make!( rank: Taxon::SPECIES ) )
    expect( swap ).to be_valid
  end
  it "should be possible for a site curator who is not a taxon curator of a complete ancestor of the output taxon" do
    genus = Taxon.make!( rank: Taxon::GENUS )
    tf = TaxonFramework.make!( taxon: genus, rank_level: 5 )
    tc = TaxonCurator.make!( taxon_framework: tf )
    swap = TaxonSwap.make
    swap.add_input_taxon( Taxon.make!( rank: Taxon::SPECIES ) )
    swap.add_output_taxon( Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: tc.user ) )
    expect( swap ).to be_valid
  end

end

describe TaxonSwap, "destruction" do
  elastic_models( Observation, Taxon, Identification )
  before(:each) do
    prepare_swap
    enable_has_subscribers
  end
  after(:each) do
    disable_has_subscribers
  end

  it "should destroy updates" do
    Observation.make!( taxon: @input_taxon )
    @swap.committer = @swap.user
    without_delay do
      @swap.commit
    end
    @swap.reload
    expect( @swap.update_actions.to_a ).not_to be_blank
    old_id = @swap.id
    @swap.destroy
    expect( UpdateAction.where( resource_type: "TaxonSwap", resource_id: old_id ).to_a ).to be_blank
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
    @swap.committer = @swap.user
  end

  it "should duplicate conservation statuses" do
    cs = ConservationStatus.make!( taxon: @input_taxon )
    expect( @output_taxon.conservation_statuses ).to be_blank
    Delayed::Job.delete_all
    @swap.commit
    @output_taxon.reload
    Delayed::Worker.new.work_off
    expect( @output_taxon.conservation_statuses.first.status ).to eq( cs.status )
    expect( @output_taxon.conservation_statuses.first.authority ).to eq( cs.authority )
  end

  it "should duplicate taxon names" do
    name = "Bunny foo foo"
    @input_taxon.taxon_names.create(:name => name, :lexicon => TaxonName::ENGLISH)
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name}).to be_blank
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_names.detect{|tn| tn.name == name}).not_to be_blank
  end

  it "should not associate users with the duplicate taxon names" do
    name = "Bunny foo foo"
    @input_taxon.taxon_names.create( name: name, lexicon: TaxonName::ENGLISH, creator: User.make! )
    expect( @output_taxon.taxon_names.detect{|tn| tn.name == name} ).to be_blank
    @swap.commit
    @output_taxon.reload
    new_name = @output_taxon.taxon_names.detect{|tn| tn.name == name}
    expect( new_name.creator ).to be_blank
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
    expect(@output_taxon.taxon_range).not_to be_blank
  end
  
  it "should duplicate atlas if one isn't already set" do
    @user = User.make!
    a = Atlas.make!(user: @user, taxon: @input_taxon, is_active: true)
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.atlas).not_to be_blank
  end

  it "should not duplicate taxon range if one is already set" do
    tr1 = TaxonRange.make!(:taxon => @input_taxon)
    tr2 = TaxonRange.make!(:taxon => @output_taxon)
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.taxon_range).not_to be_blank
  end

  it "should not duplicate atlas if one is already set" do
    a1 = Atlas.make!(user: @user, taxon: @input_taxon, is_active: true)
    a2 = Atlas.make!(user: @user, taxon: @output_taxon, is_active: true)
    @swap.commit
    @output_taxon.reload
    expect(@output_taxon.atlas).not_to be_blank
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

  describe "for taxa with children" do
    elastic_models( Observation, Identification )

    describe "with move_children" do
      before do
        @swap.update( move_children: true )
      end
      it "should move children from the input to the output taxon" do
        child = Taxon.make!( parent: @input_taxon, rank: Taxon::GENUS )
        descendant = Taxon.make!( parent: child , rank: Taxon::SPECIES )
        without_delay { @swap.commit }
        child.reload
        descendant.reload
        expect( child.parent ).to eq @output_taxon
        expect( descendant.ancestor_ids ).to include @output_taxon.id
      end

      it "should not move inactive children from the input to the output taxon" do
        child = Taxon.make!( parent: @input_taxon, is_active: false, rank: Taxon::GENUS)
        descendant = Taxon.make!( parent: child, is_active: false, rank: Taxon::SPECIES)
        without_delay { @swap.commit }
        child.reload
        descendant.reload
        expect( child.parent ).to eq @input_taxon
        expect( descendant.ancestor_ids ).to include @input_taxon.id
      end

      describe "should make swaps for all children when swapping a" do
        it "genus" do
          @input_taxon.update( rank: Taxon::GENUS, name: "Hyla" )
          @output_taxon.update( rank: Taxon::GENUS, name: "Pseudacris" )
          child = Taxon.make!( parent: @input_taxon, rank: Taxon::SPECIES, name: "Hyla regilla" )
          [@input_taxon, @output_taxon, child].each(&:reload)
          without_delay { @swap.commit }
          [@input_taxon, @output_taxon, child].each(&:reload)
          expect( child.parent ).to eq @input_taxon
          child_swap = child.taxon_change_taxa.first.taxon_change
          expect( child_swap ).not_to be_blank
          expect( child_swap.output_taxon.name ).to eq "Pseudacris regilla"
          expect( child_swap.output_taxon.parent ).to eq @output_taxon
        end
        
        it "species" do
          @input_taxon.update( rank: Taxon::SPECIES, name: "Hyla regilla" )
          @output_taxon.update( rank: Taxon::SPECIES, name: "Pseudacris regilla" )
          child = Taxon.make!( parent: @input_taxon, rank: Taxon::SUBSPECIES, name: "Hyla regilla foo" )
          [@input_taxon, @output_taxon, child].each(&:reload)
          without_delay { @swap.commit }
          [@input_taxon, @output_taxon, child].each(&:reload)
          expect( child.parent ).to eq @input_taxon
          child_swap = child.taxon_change_taxa.first.taxon_change
          expect( child_swap ).not_to be_blank
          expect( child_swap.output_taxon.name ).to eq "Pseudacris regilla foo"
          expect( child_swap.output_taxon.parent ).to eq @output_taxon
        end
      end

      it "should swap species in a genus even if there's a subgenus" do
        @input_taxon.update( rank: Taxon::GENUS, name: "Hyla" )
        @output_taxon.update( rank: Taxon::GENUS, name: "Pseudacris" )
        subgenus = Taxon.make!( rank: Taxon::SUBGENUS, name: "Why", parent: @input_taxon )
        child = Taxon.make!( parent: subgenus, rank: Taxon::SPECIES, name: "Hyla regilla" )
        [@swap, @input_taxon, @output_taxon, child, subgenus].each(&:reload)
        without_delay { @swap.commit }
        [@input_taxon, @output_taxon, child, subgenus].each(&:reload)
        expect( subgenus.parent ).to eq @input_taxon # should have swaped the subgenus, not moved it
        expect( child.parent ).to eq subgenus
        child_swap = child.taxon_change_taxa.first.taxon_change
        expect( child_swap ).not_to be_blank
        expect( child_swap.output_taxon.name ).to eq "Pseudacris regilla"
        expect( child_swap.output_taxon.parent.name ).to eq subgenus.name
      end

      it "should move children despite a locked ancestor" do
        child = Taxon.make!( parent: @input_taxon, rank: Taxon::GENUS )
        @ancestor_taxon.update( locked: true )
        @swap.reload
        without_delay { @swap.commit }
        child.reload
        expect( child.parent ).to eq @output_taxon
      end
      
      it "should swap child species despite a locked ancestor" do
        @input_taxon.update( rank: Taxon::GENUS, name: "Hyla" )
        @output_taxon.update( rank: Taxon::GENUS, name: "Pseudacris" )
        child = Taxon.make!( parent: @input_taxon, rank: Taxon::SPECIES, name: "Hyla regilla" )
        @ancestor_taxon.update( locked: true )
        [@input_taxon, @output_taxon, child].each(&:reload)
        without_delay { @swap.commit }
        [@input_taxon, @output_taxon, child].each(&:reload)
        expect( child.parent ).to eq @input_taxon
        child_swap = child.taxon_change_taxa.first.taxon_change
        expect( child_swap ).not_to be_blank
        expect( child_swap.output_taxon.name ).to eq "Pseudacris regilla"
        expect( child_swap.output_taxon.parent ).to eq @output_taxon
      end
      
      it "should move children despite a taxon framework with taxon curators" do
        child = Taxon.make!( parent: @input_taxon, rank: Taxon::GENUS )
        tf = TaxonFramework.make!(taxon: @ancestor_taxon, rank_level: 5)
        user = make_curator
        tc = TaxonCurator.make!( taxon_framework: tf, user: user)
        tc.reload
        @swap.reload
        @swap.committer = user
        without_delay { @swap.commit }
        child.reload
        expect( child.parent ).to eq @output_taxon
      end
      
      it "should swap child species despite a taxon framework with taxon curators" do
        @input_taxon.update( rank: Taxon::GENUS, name: "Hyla" )
        @output_taxon.update( rank: Taxon::GENUS, name: "Pseudacris" )
        child = Taxon.make!( parent: @input_taxon, rank: Taxon::SPECIES, name: "Hyla regilla" )
        tf = TaxonFramework.make!(taxon: @ancestor_taxon, rank_level: 5)
        user = make_curator
        tc = TaxonCurator.make!( taxon_framework: tf, user: user)
        tc.reload
        [@input_taxon, @output_taxon, child].each(&:reload)
        @swap.committer = user
        without_delay { @swap.commit }
        [@input_taxon, @output_taxon, child].each(&:reload)
        expect( child.parent ).to eq @input_taxon
        child_swap = child.taxon_change_taxa.first.taxon_change
        expect( child_swap ).not_to be_blank
        expect( child_swap.output_taxon.name ).to eq "Pseudacris regilla"
        expect( child_swap.output_taxon.parent ).to eq @output_taxon
      end
    
    end

    describe "without move_children" do
      it "should not move children" do
        family1 = Taxon.make!( rank: Taxon::FAMILY )
        family2 = Taxon.make!( rank: Taxon::FAMILY )
        genus = Taxon.make!( rank: Taxon::GENUS, parent: family1 )
        swap = TaxonSwap.make( move_children: false )
        swap.add_input_taxon( family1 )
        swap.add_output_taxon( family2 )
        swap.save!
        swap.committer = swap.user
        expect {
          swap.commit
        }.to raise_error TaxonChange::ActiveChildrenError
      end

      it "should not make a swap" do
        genus1 = Taxon.make!( rank: Taxon::GENUS, name: "Canis" )
        genus2 = Taxon.make!( rank: Taxon::GENUS, name: "Dogis" )
        species = Taxon.make!( rank: Taxon::SPECIES, parent: genus1, name: "Canis lupus" )
        swap = TaxonSwap.make( move_children: false )
        swap.add_input_taxon( genus1 )
        swap.add_output_taxon( genus2 )
        swap.save!
        swap.committer = swap.user
        expect {
          swap.commit
        }.to raise_error TaxonChange::ActiveChildrenError
      end
    end
  end
  
  it "should raise error if the output taxon is a descendant of the input taxon" do
    @ancestor_taxon.update( rank: Taxon::GENUS )
    @input_taxon.update( rank: Taxon::SPECIES, name: "Hyla regilla" )
    @output_taxon.update( rank: Taxon::SUBSPECIES, name: "Pseudacris regilla regilla", parent: @input_taxon )
    child = @output_taxon
    @swap.update(move_children: true)
    [@input_taxon, @output_taxon, child].each(&:reload)
    expect {
      @swap.commit
    }.to raise_error TaxonChange::RankLevelError
  end

  it "should raise an error if commiter is not a taxon curator of a taxon framework of the input taxon" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
    tf = TaxonFramework.make!( taxon: superfamily, rank_level: 5 )
    tc = TaxonCurator.make!( taxon_framework: tf )
    @swap.input_taxon.update( parent: superfamily, current_user: tc.user )
    expect {
      @swap.commit
    }.to raise_error TaxonChange::PermissionError
  end
  
  it "should raise an error if commiter is not a taxon curator of a taxon framework of inactive output taxon" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
    tf = TaxonFramework.make!( taxon: superfamily, rank_level: 5 )
    tc = TaxonCurator.make!( taxon_framework: tf )
    @swap.output_taxon.update( parent: superfamily, current_user: tc.user, is_active: false )
    expect {
      @swap.commit
    }.to raise_error TaxonChange::PermissionError
  end
  
  it "should not raise an error if commiter is not a taxon curator of a taxon framework of active output taxon" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
    tf = TaxonFramework.make!( taxon: superfamily, rank_level: 5 )
    tc = TaxonCurator.make!( taxon_framework: tf )
    @swap.output_taxon.update( parent: superfamily, current_user: tc.user, is_active: true )
    @output_taxon.reload
    expect {
      @swap.commit
    }.not_to raise_error # TaxonChange::PermissionError
  end
  
  it "should raise an error if input taxon has active children" do
    child = Taxon.make!( rank: Taxon::GENUS, parent: @swap.input_taxon )
    expect {
      @swap.commit
    }.to raise_error TaxonChange::ActiveChildrenError
  end
  
  it "should not raise an error if input taxon has active children but move children is checked" do
    child = Taxon.make!( rank: Taxon::GENUS, parent: @swap.input_taxon )
    @swap.update( move_children: true )
    expect {
      @swap.commit
    }.not_to raise_error # TaxonChange::ActiveChildrenError
  end
  

  describe "for input taxa with reverted changes" do
    it "should not die in an infinite loop" do
      @swap.commit
      Delayed::Worker.new.work_off

      swap2 = TaxonSwap.make( committer: @swap.committer )
      swap2.add_input_taxon( @swap.output_taxon )
      swap2.add_output_taxon( @swap.input_taxon )
      swap2.commit
      Delayed::Worker.new.work_off

      swap3 = TaxonSwap.make( committer: @swap.committer )
      swap3.add_input_taxon( @swap.input_taxon )
      swap3.add_output_taxon( Taxon.make!( is_active: false, rank: @swap.input_taxon.rank ) )
      swap3.save!
      swap3.reload
      @swap.reload
      expect( @swap ).to be_committed
      expect( @swap.input_taxon ).to be_is_active
      expect( @swap.output_taxon ).not_to be_is_active
      expect( swap3.input_taxon ).to be_is_active
      expect( swap3.output_taxon ).not_to be_is_active
      expect { swap3.commit }.not_to raise_error
    end
  end

  describe "when sole identifier of input taxon has opted out of taxon changes" do
    elastic_models( Observation, Identification )

    it "should re-evalute probable taxa" do
      o = Observation.make!
      i1 = Identification.make!(
        taxon: @ancestor_taxon,
        observation: o,
        user: o.user
      )
      i2 = Identification.make!(
        taxon: @input_taxon,
        observation: o,
        user: User.make!( prefers_automatic_taxonomic_changes: false )
      )
      expect( o.taxon ).to eq @input_taxon
      @swap.commit
      Delayed::Worker.new.work_off
      o.reload
      expect( o.identifications.current.map(&:taxon_id) ).to include i2.taxon_id
      expect( o.taxon ).to eq @ancestor_taxon
    end
  end
end

describe TaxonSwap, "commit_records" do
  elastic_models( Observation, Identification )
  before(:each) do
    prepare_swap
    enable_has_subscribers
  end
  after { disable_has_subscribers }

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
    }.to change(UpdateAction, :count).by(1)
  end

  it "should generate updates for people who don't want automation" do
    u = User.make!(:prefers_automatic_taxonomic_changes => false)
    expect(u.prefers_automatic_taxonomic_changes?).not_to be true
    o = Observation.make!(:taxon => @input_taxon, :user => u)
    expect {
      @swap.commit_records
    }.to change(UpdateAction, :count).by(1)
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
    }.to change(UpdateAction, :count).by(1)
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

  it "should log listed taxa if taxon changed" do
    @user = User.make!
    atlas_place = make_place_with_geom(admin_level: 0)
    atlas = Atlas.make!(user: @user, taxon: @input_taxon, is_active: false)
    atlas_place_check_list = List.find(atlas_place.check_list_id)
    check_listed_taxon = atlas_place_check_list.add_taxon(@input_taxon, options = {user_id: @user.id})
    expect(ListedTaxonAlteration.where(place_id: atlas_place.id, taxon_id: @input_taxon.id).count).to eq(0)
    expect(ListedTaxonAlteration.where(place_id: atlas_place.id, taxon_id: @output_taxon.id).count).to eq(0)
    atlas.is_active = true
    atlas.save!
    without_delay{ @swap.commit_records }
    # Delayed::Worker.new.work_off
    check_listed_taxon.reload
    expect(ListedTaxonAlteration.where(place_id: atlas_place.id, taxon_id: @output_taxon.id).count).not_to eq(0)
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

  it "should set a current identification's previous_observation_taxon if it is the input" do
    o = Observation.make!( taxon: @input_taxon )
    g = Taxon.make!( rank: Taxon::GENUS )
    s = Taxon.make!( rank: Taxon::SPECIES, parent: g )
    ident = Identification.make!( observation: o, taxon: s )
    expect( ident.previous_observation_taxon ).to eq @input_taxon
    @swap.commit_records
    ident.reload
    expect( ident.previous_observation_taxon ).to eq @output_taxon
  end
  
  it "should commit a taxon swap with childless input taxon with rank level coarser than the output taxon rank level" do
    other_swap = TaxonSwap.make
    other_input_genus = Taxon.make!( is_active: false, rank: Taxon::GENUS )
    other_swap.add_input_taxon( other_input_genus )
    other_swap.add_output_taxon( Taxon.make!( is_active: false, rank: Taxon::SPECIES ) )
    other_swap.committer = make_admin
    other_swap.save!
    expect {
      other_swap.commit
    }.not_to raise_error # TaxonChange::RankLevelError
  end
  
  it "should not commit a taxon swap without all input taxon child rank levels finer than the output taxon rank level" do
    other_swap = TaxonSwap.make
    other_input_genus = Taxon.make!( is_active: true, rank: Taxon::GENUS )
    child = Taxon.make!( is_active: true, parent: other_input_genus, rank: Taxon::SPECIES )
    other_swap.add_input_taxon( other_input_genus )
    other_swap.add_output_taxon( Taxon.make!( is_active: false, rank: Taxon::SPECIES ) )
    other_swap.move_children = true
    other_swap.committer = make_admin
    other_swap.save!
    expect {
      other_swap.commit
    }.to raise_error TaxonChange::RankLevelError
  end
  
  it "should commit a taxon swap with all input taxon child rank levels finer than the output taxon rank level" do
    other_swap = TaxonSwap.make
    other_input_genus = Taxon.make!( is_active: true, rank: Taxon::GENUS )
    child = Taxon.make!( is_active: true, parent: other_input_genus, rank: Taxon::SPECIES )
    other_swap.add_input_taxon( other_input_genus )
    other_swap.add_output_taxon( Taxon.make!( is_active: false, rank: Taxon::GENUS ) )
    other_swap.move_children = true
    other_swap.committer = make_admin
    other_swap.save!
    expect {
      other_swap.commit
    }.not_to raise_error # TaxonChange::RankLevelError
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
    ident = Identification.make!( observation: o, taxon: @input_taxon )
    ident.update(
      skip_set_previous_observation_taxon: true,
      previous_observation_taxon: other_swap.input_taxon
    )
    expect( ident ).to be_disagreement
    expect( ident.previous_observation_taxon ).to eq other_swap.input_taxon
    expect( ident.previous_observation_taxon ).not_to be_is_active
    @swap.commit_records
    o.reload
    new_ident = o.identifications.current.where( user_id: ident.user_id ).first
    expect( new_ident.previous_observation_taxon ).to eq other_swap.output_taxon
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
    l.update(:user => nil)
    expect(l.user).to be_blank
    lt = ListedTaxon.make!(:taxon => @input_taxon, :list => l)
    lt.update(:user => nil)
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

  it "should not update records if input and output taxa are identical" do
    tc = make_taxon_swap
    o = Observation.make!( taxon: tc.input_taxon )
    tc.input_taxon.merge(tc.output_taxon)
    tc.reload
    expect( tc.input_taxon ).to eq tc.output_taxon
    expect( o.identifications.count ).to eq 1
    tc.commit_records rescue nil
    expect( o.identifications.count ).to eq 1
  end

  it "should not add in ID for the observer that matches the obs taxon if the observer has no matching ID" do
    tc = make_taxon_swap
    o = Observation.make!
    t = tc.input_taxon
    2.times do
      Identification.make!( observation: o, taxon: t )
    end
    o.reload
    expect( o.taxon ).to eq t
    expect( o.identifications.by( o.user ) ).to be_blank
    tc.commit_records
    expect( o.identifications.by( o.user ) ).to be_blank
  end

  it "should update observation fields of type taxon" do
    of = ObservationField.make!( datatype: ObservationField::TAXON )
    ofv = ObservationFieldValue.make!( observation_field: of, value: @swap.input_taxon.id )
    @swap.commit_records
    ofv.reload
    expect( ofv.value ).to eq @swap.output_taxon.id.to_s
  end

  it "should not change the quality_grade of an RG observation" do
    genus = Taxon.make!( rank: Taxon::GENUS, name: "Genus" )
    input_taxon = Taxon.make!( rank: Taxon::SPECIES, name: "Species one", parent: genus )
    output_taxon = Taxon.make!( rank: Taxon::SPECIES, name: "Species two", parent: genus )
    swap = TaxonSwap.make
    swap.add_input_taxon( input_taxon )
    swap.add_output_taxon( output_taxon )
    swap.save!
    o = make_research_grade_observation( taxon: swap.input_taxon )
    swap.commit_records
    o.reload
    expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
  end

  it "should update a listed taxon's taxon when last observation exists" do
    tc = make_taxon_swap
    l = CheckList.make!
    lt = l.add_taxon tc.input_taxon
    o = make_research_grade_observation( latitude: l.place.latitude, longitude: l.place.longitude, taxon: lt.taxon )
    without_delay do
      ListedTaxon.update_cache_columns_for( lt )
    end
    lt.reload
    expect( lt.last_observation ).not_to be_blank
    tc.commit_records
    lt.reload
    expect( lt.taxon ).to eq tc.output_taxon
  end

  it "should merge listed taxa when a listed taxon for the output taxon already exists" do
    tc = make_taxon_swap
    l = CheckList.make!
    lt_input = l.add_taxon tc.input_taxon, description: "foo"
    lt_output = l.add_taxon tc.output_taxon
    tc.commit_records
    expect( ListedTaxon.find_by_id( lt_input.id ) ).to be_blank
    lt_output.reload
    expect( lt_output.description ).to eq "foo"
  end
end

describe "move_input_children_to_output" do
  it "should queue jobs to commit records for sub-swaps" do
    prepare_swap
    @swap.update( move_children: true )
    @input_taxon.update( rank: Taxon::SPECIES, name: "Hyla regilla", rank_level: Taxon::SPECIES_LEVEL )
    @output_taxon.update( rank: Taxon::SPECIES, name: "Pseudacris regilla", rank_level: Taxon::SPECIES_LEVEL )
    child = Taxon.make!( parent: @input_taxon, rank: Taxon::SUBSPECIES, name: "Hyla regilla foo", rank_level: Taxon::SUBSPECIES_LEVEL )
    [@input_taxon, @output_taxon, child, @swap].each(&:reload)
    @swap.committer = @swap.user
    @swap.commit
    [@input_taxon, @output_taxon, child].each(&:reload)
    @swap.move_input_children_to_output( @input_taxon )
    expect( Delayed::Job.all.select{ |j| j.handler =~ /commit_records/m }.size ).to eq 2
  end

  it "should preserve disagreements with the input taxon" do
    prepare_swap
    @swap.update( move_children: true )
    family = Taxon.make!( rank: Taxon::FAMILY, name: "Canidae" )
    @input_taxon.update( parent: family, rank: Taxon::GENUS, name: "Canis" )
    @output_taxon.update( parent: family, rank: Taxon::GENUS, name: "Dogis" )
    child = Taxon.make!( parent: @input_taxon, rank: Taxon::SPECIES, name: "Canis lupus" )
    @swap.committer = @swap.user
    o = Observation.make!
    i1 = Identification.make!( observation: o, taxon: child )
    i2 = Identification.make!( observation: o, taxon: @input_taxon, disagreement: true )
    expect( i2 ).to be_disagreement
    expect( i2.previous_observation_taxon ).to eq child
    @swap.commit
    Delayed::Worker.new.work_off
    o = Observation.find( o.id )
    @output_taxon.reload
    new_i2 = o.identifications.current.where( user_id: i2.user_id ).first
    expect( new_i2 ).to be_disagreement
    expect( new_i2.previous_observation_taxon ).to eq @output_taxon.children.first
  end

  it "should work make swaps for subspecies when you swap a genus" do
    input_genus = Taxon.make!( rank: Taxon::GENUS, name: "Inputgenus" )
    input_species = Taxon.make!( rank: Taxon::SPECIES, name: "Inputgenus foo", parent: input_genus )
    input_subspecies = Taxon.make!( rank: Taxon::SUBSPECIES, name: "Inputgenus foo foo", parent: input_species )
    output_genus = Taxon.make!( rank: Taxon::GENUS, name: "Outputgenus", is_active: false )
    # puts Taxon.where( "name like 'Inputgenus%'" ).all
    swap = TaxonSwap.make( move_children: true )
    swap.committer = swap.user
    swap.add_input_taxon( input_genus )
    swap.add_output_taxon( output_genus )
    swap.save!
    swap.commit
    Delayed::Worker.new.work_off
    Delayed::Worker.new.work_off
    Delayed::Worker.new.work_off
    output_genus.reload
    output_species = output_genus.children.detect{|t| t.name == "Outputgenus foo" }
    expect( output_species ).not_to be_blank
    output_subspecies = output_species.children.detect{|t| t.name == "Outputgenus foo foo" }
    expect( output_subspecies ).not_to be_blank
  end
end

def prepare_swap
  @ancestor_taxon = Taxon.make!( rank: Taxon::SUPERFAMILY, name: "Superfamily" )
  @input_taxon = Taxon.make!( rank: Taxon::FAMILY, name: "InputFamily", parent: @ancestor_taxon )
  @output_taxon = Taxon.make!( rank: Taxon::FAMILY, name: "OutputFamily", parent: @ancestor_taxon )
  @swap = TaxonSwap.make
  @swap.add_input_taxon(@input_taxon)
  @swap.add_output_taxon(@output_taxon)
  @swap.save!
end
