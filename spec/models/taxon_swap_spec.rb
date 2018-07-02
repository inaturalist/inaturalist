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

  it "should not bail if a taxon has no rank_level" do
    swap = TaxonSwap.make
    swap.add_input_taxon( Taxon.make!( rank: Taxon::SPECIES ) )
    swap.add_output_taxon( Taxon.make!( rank: "something ridiculous" ) )
    expect( swap.output_taxon.rank_level ).to be_blank
    expect(swap).to be_valid
  end

  it "should be possible for a site curator who is not a taxon curator of a complete ancestor of the input taxon" do
    genus = Taxon.make!( rank: Taxon::GENUS, complete: true )
    tc = TaxonCurator.make!( taxon: genus )
    swap = TaxonSwap.make
    swap.add_input_taxon( Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: tc.user ) )
    swap.add_output_taxon( Taxon.make!( rank: Taxon::SPECIES ) )
    expect( swap ).to be_valid
  end
  it "should be possible for a site curator who is not a taxon curator of a complete ancestor of the output taxon" do
    genus = Taxon.make!( rank: Taxon::GENUS, complete: true )
    tc = TaxonCurator.make!( taxon: genus )
    swap = TaxonSwap.make
    swap.add_input_taxon( Taxon.make!( rank: Taxon::SPECIES ) )
    swap.add_output_taxon( Taxon.make!( rank: Taxon::SPECIES, parent: genus, current_user: tc.user ) )
    expect( swap ).to be_valid
  end

end

describe TaxonSwap, "destruction" do
  before(:each) do
    enable_elastic_indexing( Observation, Taxon, Identification )
    prepare_swap
    enable_has_subscribers
  end
  after(:each) do
    disable_elastic_indexing( Observation, Taxon, Identification )
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

  it "should duplicate conservation status" do
    @input_taxon.update_attribute(:conservation_status, Taxon::IUCN_ENDANGERED)
    expect(@output_taxon.conservation_status).to be_blank
    @swap.commit
    expect(@output_taxon.conservation_status).to eq(Taxon::IUCN_ENDANGERED)
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
    expect(@output_taxon.taxon_ranges.count).to eq(1)
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
    before(:each) { enable_elastic_indexing( Observation, Identification ) }
    after(:each) { disable_elastic_indexing( Observation, Identification ) }

    it "should move children from the input to the output taxon" do
      child = Taxon.make!( parent: @input_taxon, rank: Taxon::GENUS )
      descendant = Taxon.make!( parent: child )
      without_delay { @swap.commit }
      child.reload
      descendant.reload
      expect( child.parent ).to eq @output_taxon
      expect( descendant.ancestor_ids ).to include @output_taxon.id
    end

    it "should not move inactive children from the input to the output taxon" do
      child = Taxon.make!( parent: @input_taxon, is_active: false )
      descendant = Taxon.make!( parent: child, is_active: false )
      without_delay { @swap.commit }
      child.reload
      descendant.reload
      expect( child.parent ).to eq @input_taxon
      expect( descendant.ancestor_ids ).to include @input_taxon.id
    end

    describe "should make swaps for all children when swapping a" do
      it "genus" do
        @input_taxon.update_attributes( rank: Taxon::GENUS, name: "Hyla" )
        @output_taxon.update_attributes( rank: Taxon::GENUS, name: "Pseudacris" )
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
        @input_taxon.update_attributes( rank: Taxon::SPECIES, name: "Hyla regilla" )
        @output_taxon.update_attributes( rank: Taxon::SPECIES, name: "Pseudacris regilla" )
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

    it "should not make swaps for a child if the child is itself involved in this swap" do
      @input_taxon.update_attributes( rank: Taxon::SPECIES, name: "Hyla regilla" )
      @output_taxon.update_attributes( rank: Taxon::SPECIES, name: "Pseudacris regilla", parent: @input_taxon )
      child = @output_taxon
      [@input_taxon, @output_taxon, child].each(&:reload)
      without_delay { @swap.commit }
      [@input_taxon, @output_taxon, child].each(&:reload)
      expect( child.parent ).to eq @input_taxon
      expect( child.taxon_change_taxa ).to be_blank
    end
  end

  it "should raise an error if commiter is not a taxon curator of a complete ancestor of the input taxon" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY, complete: true )
    tc = TaxonCurator.make!( taxon: superfamily )
    @swap.input_taxon.update_attributes( parent: superfamily, current_user: tc.user )
    expect {
      @swap.commit
    }.to raise_error TaxonChange::PermissionError
  end
  it "should raise an error if commiter is not a taxon curator of a complete ancestor of the output taxon" do
    superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY, complete: true )
    tc = TaxonCurator.make!( taxon: superfamily )
    @swap.output_taxon.update_attributes( parent: superfamily, current_user: tc.user )
    expect {
      @swap.commit
    }.to raise_error TaxonChange::PermissionError
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

end

describe TaxonSwap, "commit_records" do
  before(:each) do
    prepare_swap
    enable_elastic_indexing( Observation, Identification )
    enable_has_subscribers
  end
  after(:each) do
    disable_elastic_indexing( Observation, Identification )
    disable_has_subscribers
  end

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
    AncestryDenormalizer.denormalize
    @user = User.make!
    atlas_place = Place.make!(admin_level: 0)
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
    ident.update_attributes(
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

  it "should not update records if input and output taxa are identical" do
    tc = make_taxon_swap
    o = Observation.make!( taxon: tc.input_taxon )
    tc.input_taxon.merge(tc.output_taxon)
    tc.reload
    expect( tc.input_taxon ).to eq tc.output_taxon
    expect( o.identifications.count ).to eq 1
    tc.commit_records
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
end

describe "move_input_children_to_output" do
  it "should queue jobs to commit records for sub-swaps" do
    prepare_swap
    @input_taxon.update_attributes( rank: Taxon::SPECIES, name: "Hyla regilla", rank_level: Taxon::SPECIES_LEVEL )
    @output_taxon.update_attributes( rank: Taxon::SPECIES, name: "Pseudacris regilla", rank_level: Taxon::SPECIES_LEVEL )
    child = Taxon.make!( parent: @input_taxon, rank: Taxon::SUBSPECIES, name: "Hyla regilla foo", rank_level: Taxon::SUBSPECIES_LEVEL )
    [@input_taxon, @output_taxon, child].each(&:reload)
    @swap.committer = @swap.user
    @swap.commit
    [@input_taxon, @output_taxon, child].each(&:reload)
    @swap.move_input_children_to_output( @input_taxon )
    expect( Delayed::Job.all.select{ |j| j.handler =~ /commit_records/m }.size ).to eq 2
  end

  it "should preserve disagreements with the input taxon" do
    prepare_swap
    family = Taxon.make!( rank: Taxon::FAMILY, name: "Canidae" )
    @input_taxon.update_attributes( parent: family, rank: Taxon::GENUS, name: "Canis" )
    @output_taxon.update_attributes( parent: family, rank: Taxon::GENUS, name: "Dogis" )
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
end

def prepare_swap
  superfamily = Taxon.make!( rank: Taxon::SUPERFAMILY )
  @input_taxon = Taxon.make!( rank: Taxon::FAMILY, name: "InputFamily", parent: superfamily )
  @output_taxon = Taxon.make!( rank: Taxon::FAMILY, name: "OutputFamily", parent: superfamily )
  @swap = TaxonSwap.make
  @swap.add_input_taxon(@input_taxon)
  @swap.add_output_taxon(@output_taxon)
  @swap.save!
end
