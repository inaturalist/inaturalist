require File.dirname(__FILE__) + '/../spec_helper.rb'

def update_cache_columns_jobs
  Delayed::Job.where("handler LIKE '%update_cache_columns_for%'").count
end

describe ListedTaxon do
  elastic_models( Observation, Place )

  it { is_expected.to belong_to :list }
  it { is_expected.to belong_to :taxon }
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :place }
  it { is_expected.to belong_to :taxon_range }
  it { is_expected.to belong_to :source }
  it { is_expected.to belong_to(:first_observation).class_name("Observation").with_foreign_key "first_observation_id" }
  it { is_expected.to belong_to(:last_observation).class_name("Observation").with_foreign_key "last_observation_id" }
  it { is_expected.to belong_to(:simple_place).with_foreign_key(:place_id).class_name "Place" }
  it { is_expected.to have_many(:comments).dependent :destroy }

  it { is_expected.to validate_presence_of :list_id }
  it { is_expected.to validate_presence_of :taxon_id }
  it { is_expected.to validate_uniqueness_of(:taxon_id).scoped_to(:list_id).with_message "is already on this list" }
  it { is_expected.to validate_length_of(:description).is_at_most(1000).allow_blank }
  it do
    is_expected.to validate_inclusion_of(:occurrence_status_level).in_array(ListedTaxon::OCCURRENCE_STATUS_LEVELS.keys)
                                                                  .allow_blank
  end
  it do
    is_expected.to validate_inclusion_of(:establishment_means).in_array(ListedTaxon::ESTABLISHMENT_MEANS)
                                                              .allow_blank.allow_nil
  end

  it "should be invalid when check list fields set on a non-check list" do
    list = List.make!
    check_list = CheckList.make!
    listed_taxon = ListedTaxon.new(:list => list, :taxon => Taxon.make!,
      :occurrence_status_level => ListedTaxon::OCCURRENCE_STATUS_LEVELS.keys.first)
    expect(listed_taxon).not_to be_valid
    listed_taxon.list = check_list
    expect(listed_taxon).to be_valid
  end

  describe "creation" do
    let(:taxon) { build_stubbed :taxon }
    let(:first_observation) { build_stubbed :observation, taxon: taxon, observed_on_string: 1.minute.ago.utc.to_s }
    let(:user) { first_observation.user }
    let(:last_observation) { build_stubbed :observation, taxon: taxon, user: user, observed_on_string: Time.now.utc.to_s }
    let(:list) { build_stubbed :list, user: user }

    subject { build_stubbed :listed_taxon, taxon: taxon, list: list }
    
    it "should not set last observation" do
      expect(subject.last_observation_id).to be_blank
    end
    
    it "should not set first observation" do
      expect(subject.first_observation_id).to be_blank
    end
    
    it "should not set observations_count" do
      expect(subject.observations_count).to eq 0
    end
  end
  
  describe "creation for check lists" do
    let(:place) { build_stubbed :place, :with_geom, :with_check_list }
    let(:check_list) { place.check_list }
    let(:user) { build_stubbed :user }
    let(:source) { build_stubbed :source }
    let(:user_check_list) { build_stubbed :check_list, place: place, title: "Foo!", user: user, source: source }

    describe "not using callbacks" do
      it "should make sure the user matches the check list user" do
        lt = user_check_list.listed_taxa.build(taxon: build_stubbed(:taxon), user: user)
        expect(lt).to be_valid
        lt = user_check_list.listed_taxa.build(taxon: build_stubbed(:taxon), user: build_stubbed(:user))
        expect(lt).not_to be_valid
      end

      it "should allow curators to add to owned check lists" do
        lt = user_check_list.listed_taxa.build(taxon: build_stubbed(:taxon), user: build_stubbed(:user, :as_curator))
        expect(lt).to be_valid
      end

      it "should inherit the check list's source" do
        lt = user_check_list.listed_taxa.create(taxon: build_stubbed(:taxon), user: user)
        expect(lt.source_id).to be(user_check_list.source_id)
      end
    end

    describe "using callbacks" do
      before(:each) do |example|
        return if example.metadata[:skip_setup]
        @place = make_place_with_geom
        @check_list = @place.check_list
        expect(@check_list).to be_is_default
        @user = User.make!
        @user_check_list = @place.check_lists.create(:title => "Foo!", :user => @user, :source => Source.make!)
      end

      describe "cached columns" do
        before do
          @taxon = Taxon.make!(:rank => "species")
          @first_observation = make_research_grade_observation(:observed_on_string => "2009-01-03",
                                                               :taxon => @taxon, :latitude => @place.latitude, :longitude => @place.longitude)
          @inbetween_observation = Observation.make!(:observed_on_string => "2009-02-02",
                                                     :taxon => @taxon, :latitude => @place.latitude, :longitude => @place.longitude)
          @last_observation = make_research_grade_observation(:observed_on_string => "2009-03-05",
                                                              :taxon => @taxon, :latitude => @place.latitude, :longitude => @place.longitude)
          expect(@first_observation.places).to include @place
          expect(@last_observation.places).to include @place
        end
        it "should set first observation to the first research grade observation added" do
          lt = without_delay { ListedTaxon.make!(:list => @check_list, :place => @place, :taxon => @taxon) }
          expect(lt.first_observation).to eq @first_observation
        end
        it "should set last observation to the last research grade observation observed" do
          lt = without_delay { ListedTaxon.make!(:list => @check_list, :place => @place, :taxon => @taxon) }
          expect(lt.last_observation).to eq @last_observation
        end
      end

      it "should set establishment_means to native if there is a native listing for a child place" do
        child_place = make_place_with_geom(:parent => @place)
        t = Taxon.make!
        child_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::NATIVE)
        lt = @check_list.add_taxon(t)
        expect(lt.establishment_means).to eq(ListedTaxon::NATIVE)
      end

      it "should set establishment_means to introduced if there is a introduced listing for a parent place" do
        parent_place = make_place_with_geom
        place = make_place_with_geom(:parent => parent_place)
        t = Taxon.make!
        parent_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::INTRODUCED)
        lt = place.check_list.add_taxon(t)
        expect(lt.establishment_means).to eq(ListedTaxon::INTRODUCED)
      end

      it "should log listed_taxon_alterations if listed_taxa has_atlas_or_complete_set? on create" do
        taxon = Taxon.make!
        atlas_place = make_place_with_geom(admin_level: 0)
        atlas = Atlas.make!(user: @user, taxon: taxon, is_active: true)
        atlas_place_check_list = List.find(atlas_place.check_list_id)
        check_listed_taxon = atlas_place_check_list.add_taxon(taxon, options = {user_id: @user.id})
        expect(check_listed_taxon.has_atlas_or_complete_set?).to be true
        expect(ListedTaxonAlteration.where(
            taxon_id: taxon.id,
            user_id: @user.id,
            place_id: atlas_place.id,
            action: "listed"
        ).first).not_to be_blank
      end
    end
  end
  
  describe "destroy" do
    it "should log listed_taxon_alterations if listed_taxa has_atlas_or_complete_set? on destroy" do
      taxon = Taxon.make!
      atlas_place = make_place_with_geom(admin_level: 0)
      atlas_place_check_list = List.find(atlas_place.check_list_id)
      @user = User.make!
      check_listed_taxon = atlas_place_check_list.add_taxon(taxon, options = {user_id: @user.id})
      expect(check_listed_taxon.has_atlas_or_complete_set?).to be false
      @other_user = User.make!
      atlas = Atlas.make!(user: @other_user, taxon: taxon, is_active: true)
      expect(check_listed_taxon.has_atlas_or_complete_set?).to be true
      @other_user = User.make!
      check_listed_taxon.updater = @other_user
      check_listed_taxon.destroy
      expect(ListedTaxonAlteration.where(
        taxon_id: taxon.id,
        user_id: @other_user.id,
        place_id: atlas_place.id,
        action: "unlisted"
      ).first).not_to be_blank
    end
  end

  describe "check list removal" do
    let(:place) { build_stubbed :place, :with_geom, :with_check_list }
    let(:check_list) { place.check_list }

    describe "auto removal" do
      it "should work for vanilla" do
        lt = build_stubbed :listed_taxon, list: check_list, place: place
        expect(lt).to be_auto_removable_from_check_list
      end

      it "should not work if first observation" do
        lt = build_stubbed :listed_taxon, list: check_list, first_observation: build_stubbed(:observation)
        expect(lt).not_to be_auto_removable_from_check_list
      end

      it "should not work if user" do
        lt = build_stubbed :listed_taxon, list: check_list, user: build_stubbed(:user)
        expect(lt).not_to be_auto_removable_from_check_list
      end

      it "should not work if taxon range" do
        lt = build_stubbed :listed_taxon, list: check_list, taxon_range: build_stubbed(:taxon_range)
        expect(lt).not_to be_auto_removable_from_check_list
      end

      it "should not work if source" do
        lt = build_stubbed :listed_taxon, list: check_list, source: build_stubbed(:source)
        expect(lt).not_to be_auto_removable_from_check_list
      end
    end

    describe "user removal" do
      let(:user) { build :user }

      it "should work for user who added" do
        lt = build :listed_taxon, list: check_list, user: user
        expect(lt).to be_removable_by user
      end

      it "should work for lists the user owns" do
        list = build_stubbed :list, user: user
        lt = build_stubbed :listed_taxon, list: list
        expect(lt).to be_removable_by user
      end

      it "should not work if first observation" do
        lt = build_stubbed :listed_taxon, list: check_list, first_observation: build_stubbed(:observation)
        expect(lt).not_to be_removable_by user
      end

      it "should not work if remover is not user" do
        lt = build_stubbed :listed_taxon, list: check_list, user: build_stubbed(:user)
        expect(lt).not_to be_removable_by user
      end

      it "should not work if taxon range" do
        lt = build_stubbed :listed_taxon, list: check_list, taxon_range: build_stubbed(:taxon_range)
        expect(lt).not_to be_removable_by user
      end

      it "should not work if source" do
        lt = build_stubbed :listed_taxon, list: check_list, source: build_stubbed(:source)
        expect(lt).not_to be_removable_by user
      end

      it "should work for admins" do
        lt = build_stubbed :listed_taxon, list: check_list, first_observation: build_stubbed(:observation)
        user = build_stubbed :user, :as_admin
        expect(lt).to be_removable_by user
      end

      it "should work if there's no source" do
        lt = build_stubbed :listed_taxon, list: check_list
        expect(lt.citation_object).to be_blank
        expect(lt).to be_removable_by user
      end
    end
  end
  
  describe "updating" do
    it "should fail if occurrence_status set to absent and there is a confirming observation" do
      check_list = build_stubbed :check_list
      taxon = build_stubbed :taxon
      observation = build_stubbed :observation, :research_grade,
                      latitude: check_list.place.latitude,
                      longitude: check_list.place.longitude,
                      taxon: taxon
      lt = build_stubbed :listed_taxon, list: check_list, taxon: taxon, first_observation: observation
      expect(lt).to be_valid
      lt.occurrence_status_level = ListedTaxon::ABSENT
      expect(lt).not_to be_valid
      expect(lt.errors[:occurrence_status_level]).not_to be_blank
    end

    it "should not allow endemic taxa for continent-level places" do
      place = build_stubbed :place, :with_geom, admin_level: Place::CONTINENT_LEVEL
      lt = build_stubbed :listed_taxon, place: place, list: place.check_list
      lt.establishment_means = ListedTaxon::ENDEMIC
      expect( lt ).not_to be_valid
      expect( lt.errors[:establishment_means] ).not_to be_blank
    end

    it "should not allow endemic taxa for continents" do
      place = build_stubbed :place, :with_geom, admin_level: Place::CONTINENT
      lt = build_stubbed :listed_taxon, place: place, list: place.check_list
      lt.establishment_means = ListedTaxon::ENDEMIC
      expect( lt ).not_to be_valid
      expect( lt.errors[:establishment_means] ).not_to be_blank
    end

    it "should reindex observations of taxon when establishment means changes to introduced" do
      l = CheckList.make!
      t = Taxon.make!
      lt = ListedTaxon.make!( list: l, taxon: t )
      expect( lt.establishment_means ).to be_blank
      o = Observation.make!( taxon: t, latitude: l.place.latitude, longitude: l.place.longitude )
      Delayed::Worker.new.work_off
      es_o = Observation.elastic_search( where: { id: o.id } ).results[0]
      expect( es_o.taxon.introduced ).to be false
      lt.update( establishment_means: ListedTaxon::INTRODUCED )
      Delayed::Worker.new.work_off
      es_o = Observation.elastic_search( where: { id: o.id } ).results[0]
      expect( es_o.taxon.introduced ).to be true
    end
  end
  
  describe "citation object" do
    it "should set occurrence_status to present if set"
  end
  
  describe "merge" do
    before(:each) do
      @keeper = ListedTaxon.make!
      @reject = ListedTaxon.make!
    end
    
    it "should destroy the reject" do
      @keeper.merge(@reject)
      expect(ListedTaxon.find_by_id(@reject.id)).to be_blank
    end
    
    it "should add comments from the reject to the keeper" do
      comment = Comment.make!(:parent => @reject)
      expect(@keeper.comments.count).to be(0)
      @keeper.merge(@reject)
      expect(@keeper.comments.count).to be(1)
    end
    
    it "should add attributes from the reject to the keeper" do
      @reject.update_attribute(:description, "this thing is dust")
      @keeper.merge(@reject)
      expect(@keeper.description).to eq "this thing is dust"
    end
    
    it "should not override attributes in the keeper" do
      @keeper.update_attribute(:description, "i will survive")
      @reject.update_attribute(:description, "i'm doomed!")
      @keeper.merge(@reject)
      expect(@keeper.description).to eq "i will survive"
    end
  end
  
  describe "merge_duplicates" do
    it "should keep the earliest listed taxon" do
      keeper = ListedTaxon.make!
      reject = ListedTaxon.make!(:list => keeper.list)
      ListedTaxon.where(id: reject.id).update_all(taxon_id: keeper.taxon_id)
      ListedTaxon.merge_duplicates
      expect(ListedTaxon.find_by_id(keeper.id)).not_to be_blank
      expect(ListedTaxon.find_by_id(reject.id)).to be_blank
    end

    it "should work for multiple duplicates" do
      keeper = ListedTaxon.make!
      rejects = []
      3.times do
        reject = ListedTaxon.make!(:list => keeper.list)
        ListedTaxon.where(id: reject.id).update_all(taxon_id: keeper.taxon_id)
        rejects << reject
      end
      ListedTaxon.merge_duplicates
      expect(ListedTaxon.find_by_id(keeper.id)).not_to be_blank
      rejects.each do |reject|
        expect(ListedTaxon.find_by_id(reject.id)).to be_blank
      end
    end
  end
  
  describe "cache_columns" do
    before(:each) do
      @place = make_place_with_geom(:name => "foo to the bar")
      @place.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
      @check_list = @place.check_list
      @taxon = Taxon.make!(:rank => Taxon::SPECIES)
    end
    
    it "should set first observation to obs of desc taxa" do
      subspecies = Taxon.make!(:rank => Taxon::SUBSPECIES, :parent => @taxon)
      o = make_research_grade_observation(:taxon => subspecies, :latitude => @place.latitude, :longitude => @place.longitude)
      lt = ListedTaxon.make!(:list => @check_list, :place => @place, :taxon => @taxon)
      without_delay do
        ListedTaxon.update_cache_columns_for(lt)
      end
      lt.reload
      expect(lt.first_observation_id).to eq o.id
    end
  end

  describe "validation for comprehensive check lists" do
    before(:each) do
      @parent = Taxon.make!(rank: Taxon::GENUS)
      @taxon = Taxon.make!(parent: @parent, rank: Taxon::SPECIES)
      @place = make_place_with_geom
      @check_list = CheckList.make!(:place => @place, :taxon => @parent, :comprehensive => true)
      @check_listed_taxon = @check_list.add_taxon(@taxon)
    end
  
    it "should fail if a comprehensive check list that doesn't contain this taxon exists for a parent taxon" do
      t = Taxon.make!(parent: @parent, rank: Taxon::SPECIES)
      expect(@check_list.taxon_ids).not_to include(t.id)
      lt = @place.check_list.add_taxon(t)
      expect(lt).not_to be_valid
      expect(lt.errors[:taxon_id]).not_to be_blank
    end
  
    it "should fail if a comprehensive check list that doesn't contain this taxon exists for a parent taxon in an ancestor place" do
      t = Taxon.make!(parent: @parent, rank: Taxon::SPECIES)
      expect(@check_list.taxon_ids).not_to include(t.id)
      p = make_place_with_geom(:parent => @place)
      lt = p.check_list.add_taxon(t)
      expect(lt).not_to be_valid
      expect(lt.errors[:taxon_id]).not_to be_blank
    end
  
    it "should pass if a comprehensive check lists that does contain this taxon exists for a parent taxon" do
      t = Taxon.make!(parent: @parent, rank: Taxon::SPECIES)
      clt = @check_list.add_taxon(t)
      expect(@check_list.taxon_ids).to include(t.id)
      lt = @place.check_list.add_taxon(t)
      expect(lt).to be_valid
    end
  
    it "should pass if a comprehensive check list that doesn't contain this taxon exists for a parent taxon and there is a confirming observation" do
      t = Taxon.make!(parent: @parent, rank: Taxon::SPECIES)
      o = make_research_grade_observation(:taxon => t, :latitude => @place.latitude, :longitude => @place.longitude)
      expect(@check_list.taxon_ids).not_to include(t.id)
      lt = @place.check_list.add_taxon(t, :first_observation => o)
      expect(lt).to be_valid
    end
  end

  describe "establishment means propagation" do
    let(:parent) { make_place_with_geom }
    let(:place) { make_place_with_geom(:parent => parent) }
    let(:child) { make_place_with_geom(:parent => place) }
    let(:taxon) { Taxon.make! }
    let(:parent_listed_taxon) { parent.check_list.add_taxon(taxon) }
    let(:place_listed_taxon) { place.check_list.add_taxon(taxon) }
    let(:child_listed_taxon) { child.check_list.add_taxon(taxon) }
    it "should bubble up for native" do
      expect(parent_listed_taxon.establishment_means).to be_blank
      place_listed_taxon.update(:establishment_means => ListedTaxon::NATIVE)
      parent_listed_taxon.reload
      expect(parent_listed_taxon.establishment_means).to eq(place_listed_taxon.establishment_means)
    end

    it "should bubble up for endemic" do
      expect(parent_listed_taxon.establishment_means).to be_blank
      place_listed_taxon.update(:establishment_means => ListedTaxon::ENDEMIC)
      parent_listed_taxon.reload
      expect(parent_listed_taxon.establishment_means).to eq(place_listed_taxon.establishment_means)
    end

    it "should not trickle down for native" do
      expect(child_listed_taxon.establishment_means).to be_blank
      place_listed_taxon.update(:establishment_means => ListedTaxon::NATIVE)
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to be_blank
    end

    it "should trickle down for introduced" do
      expect(child_listed_taxon.establishment_means).to be_blank
      place_listed_taxon.update(:establishment_means => ListedTaxon::INTRODUCED)
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq(place_listed_taxon.establishment_means)
    end

    it "should not bubble up for introduced" do
      expect(parent_listed_taxon.establishment_means).to be_blank
      place_listed_taxon.update(:establishment_means => ListedTaxon::INTRODUCED)
      parent_listed_taxon.reload
      expect(parent_listed_taxon.establishment_means).to be_blank
    end

    it "should not alter previous settings" do
      parent_listed_taxon.update(:establishment_means => ListedTaxon::INTRODUCED)
      place_listed_taxon.update(:establishment_means => ListedTaxon::NATIVE)
      parent_listed_taxon.reload
      expect(parent_listed_taxon.establishment_means).to eq(ListedTaxon::INTRODUCED)
    end

    it "should not alter est means of other taxa" do
      new_parent_listed_taxon = parent.check_list.add_taxon(Taxon.make!)
      place_listed_taxon.update(:establishment_means => ListedTaxon::NATIVE)
      new_parent_listed_taxon.reload
      expect(new_parent_listed_taxon.establishment_means).to be_blank
    end

    it "trickle down should be forceable" do
      expect(child_listed_taxon.establishment_means).to be_blank
      place_listed_taxon.update(:establishment_means => ListedTaxon::INTRODUCED)
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::INTRODUCED
      place_listed_taxon.update(:establishment_means => ListedTaxon::NATIVE)
      place_listed_taxon.trickle_down_establishment_means(:force => true)
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::NATIVE
    end

    it "trickle down should be forceable based on force_trickle_down_establishment_means" do
      expect(child_listed_taxon.establishment_means).to be_blank
      place_listed_taxon.update(:establishment_means => ListedTaxon::INTRODUCED)
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::INTRODUCED
      place_listed_taxon.update(:establishment_means => ListedTaxon::NATIVE, :force_trickle_down_establishment_means => true)
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::NATIVE
    end

    it "trickle should not update listed taxa for other places" do
      sibling_place = make_place_with_geom(:parent => parent)
      sibling_lt = sibling_place.check_list.add_taxon(taxon, :establishment_means => ListedTaxon::NATIVE)
      expect(sibling_lt.establishment_means).to eq ListedTaxon::NATIVE
      place_listed_taxon.update(:establishment_means => ListedTaxon::INTRODUCED)
      place_listed_taxon.trickle_down_establishment_means(:force => true)
      child_listed_taxon.reload
      expect(child_listed_taxon.establishment_means).to eq ListedTaxon::INTRODUCED
      sibling_lt.reload
      expect(sibling_lt.establishment_means).to eq ListedTaxon::NATIVE
    end
  end

  describe "cache column setting for check lists" do
    before do
      without_delay do
        @place = make_place_with_geom
        @check_list = @place.check_list
      end
    end
    it "should be queued" do
      lt = ListedTaxon.make!(:list => @check_list)
      expect(Delayed::Job.where("handler LIKE '%ListedTaxon%update_cache_columns_for%\n- #{lt.id}\n'").exists?).to be true
    end

    it "should not be queued if there's an existing job" do
      lt = ListedTaxon.make!(:list => @check_list)
      expect(Delayed::Job.where("handler LIKE '%ListedTaxon%update_cache_columns_for%\n- #{lt.id}\n'").count).to eq(1)
      lt.update(:establishment_means => ListedTaxon::NATIVE)
      expect(Delayed::Job.where("handler LIKE '%ListedTaxon%update_cache_columns_for%\n- #{lt.id}\n'").count).to eq(1)
    end
  end

  describe "parent check list syncing" do
    before do
      without_delay do
        @parent = make_place_with_geom
        @place = make_place_with_geom(:parent => @parent)
        @check_list = @place.check_list
      end
    end
    it "should be queued" do
      lt = ListedTaxon.make!(:list => @check_list)
      expect(
        Delayed::Job.all.map( &:handler_yaml ).select do |j|
          j.object.is_a?( CheckList ) && j.object.id == @check_list.id && j.method_name == :sync_with_parent
        end.length
      ).to eq( 1 )
    end

    it "should not be queued if existing job" do
      lt = ListedTaxon.make!(:list => @check_list)
      expect(
        Delayed::Job.all.map( &:handler_yaml ).select do |j|
          j.object.is_a?( CheckList ) && j.object.id == @check_list.id && j.method_name == :sync_with_parent
        end.length
      ).to eq( 1 )
      lt2 = ListedTaxon.make!(:list => @check_list)
      expect(
        Delayed::Job.all.map( &:handler_yaml ).select do |j|
          j.object.is_a?( CheckList ) && j.object.id == @check_list.id && j.method_name == :sync_with_parent
        end.length
      ).to eq( 1 )
    end
  end

  describe "a listed taxon on a non checklist" do
    before do
      @taxon = Taxon.make!
      @list = List.make!
      @first_observation = Observation.make!(:taxon => @taxon)
      @user = @first_observation.user
      @last_observation = Observation.make!(:taxon => @taxon, :user => @user, :observed_on_string => 1.minute.ago.to_s)
      @listed_taxon = ListedTaxon.make!(:taxon => @taxon, :list => @list)
      @listed_taxon.reload
    end

    it "should not be a primary listing" do
      @listed_taxon.update(:primary_listing => true)
      expect(@listed_taxon).not_to be_primary_listing
    end
  end

  describe "primary_listing" do
    before(:each) do
      @taxon = Taxon.make!
      @check_list = CheckList.make!
      @check_list_two = CheckList.make!
      @check_list_two.place = @check_list.place
      @check_list_two.save
      @check_list_two.reload
      @first_observation = Observation.make!(:taxon => @taxon)
      @user = @first_observation.user
      @last_observation = Observation.make!(:taxon => @taxon, :user => @user, :observed_on_string => 1.minute.ago.to_s)
      @listed_taxon = ListedTaxon.make!(:taxon => @taxon, :list => @check_list)
      @listed_taxon.reload

      @first_observation_two = Observation.make!(:taxon => @taxon)
      @user_two = @first_observation_two.user
      @last_observation_two = Observation.make!(:taxon => @taxon, :user => @user_two, :observed_on_string => 1.minute.ago.to_s)
      @listed_taxon_two = ListedTaxon.make!(:taxon => @taxon, :list => @check_list_two)
      @listed_taxon_two.reload
    
    end

    it "should set as first as primary listing" do
      expect(@listed_taxon.primary_listing).to be(true)
    end
    it "should set second lt as primary listing = false" do
      expect(@listed_taxon_two.primary_listing).to be(false)
    end
    it "should override attributes (like establishment means) of the non-primary listed taxon" do
      expect(@listed_taxon.primary_listing).to be(true)
      @listed_taxon.update_attribute(:establishment_means, "introduced")
      @listed_taxon_two.reload
      expect(@listed_taxon_two.establishment_means).to eq("introduced")
    end
    it "should reassign the primary to the second taxon when the original primary is destroyed" do
      expect(@listed_taxon.primary_listing).to be(true)
      @listed_taxon.destroy
      @listed_taxon_two.reload
      expect(@listed_taxon_two.primary_listing).to be(true)
      @listed_taxon_two.destroy
    end
    it "should set each lt appropriately on update" do
      @listed_taxon_two.update_attribute(:primary_listing, true)
      expect(@listed_taxon_two.primary_listing).to be(true)
      @listed_taxon.reload
      expect(@listed_taxon.primary_listing).to be(false)
    end
  end

  describe "force_update_cache_columns" do
    before do
      @place = make_place_with_geom
      @check_list = CheckList.make!(:place => @place)
      @lt = ListedTaxon.make!(list: @check_list, place: @place, primary_listing: true, taxon: Taxon.make!(rank: Taxon::SPECIES))
      @observation = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @lt.taxon)
      expect(Observation.in_place(@place)).to include @observation
      ListedTaxon.where(id: @lt).update_all(
        first_observation_id: nil,
        last_observation_id: nil,
        observations_count: nil)
      Delayed::Job.delete_all
      expect(Delayed::Job.count).to eq 0
      @lt.reload
      expect(@lt.last_observation_id).to be_nil
    end

    it "should queue a job to update cache columns when not set" do
      @lt.save 
      expect(update_cache_columns_jobs).to eq 1
      @lt.reload
      expect(@lt.last_observation_id).to be_nil
    end

    it "should not queue a job to update cache columns if a job already exists" do
      @lt.save 
      expect(update_cache_columns_jobs).to eq 1
      @lt.reload
      @lt.save
      expect(update_cache_columns_jobs).to eq 1
    end

    it "should not queue a job to update cache columns if set" do
      Delayed::Job.delete_all
      @lt.force_update_cache_columns = true
      @lt.save
      expect(update_cache_columns_jobs).to eq 0
    end

    it "should force cache columns to be set" do
      Delayed::Job.delete_all
      @lt.force_update_cache_columns = true
      @lt.save
      expect(@lt.last_observation_id).to eq @observation.id
    end
  end
end
