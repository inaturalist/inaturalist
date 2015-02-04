require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ListedTaxon do
  it "should be invalid when check list fields set on a non-check list" do
    list = List.make!
    check_list = CheckList.make!
    listed_taxon = ListedTaxon.new(:list => list, :taxon => Taxon.make!,
      :occurrence_status_level => ListedTaxon::OCCURRENCE_STATUS_LEVELS.keys.first)
    listed_taxon.should_not be_valid
    listed_taxon.list = check_list
    listed_taxon.should be_valid
  end
  
  describe "creation" do
    before(:each) do
      @taxon = Taxon.make!
      @first_observation = Observation.make!(:taxon => @taxon)
      @user = @first_observation.user
      @last_observation = Observation.make!(:taxon => @taxon, :user => @user, :observed_on_string => 1.minute.ago.to_s)
      @list = @user.life_list
      @listed_taxon = ListedTaxon.make!(:taxon => @taxon, :list => @list)
      @listed_taxon.reload
    end
    
    it "should set last observation" do
      @listed_taxon.last_observation_id.should be(@last_observation.id)
    end
    
    it "should set first observation" do
      @listed_taxon.first_observation_id.should be(@first_observation.id)
    end
    
    it "should set observations_count" do
      @listed_taxon.observations_count.should be(2)
    end
    
    it "should set observations_month_counts" do
      @listed_taxon.observations_month_counts.should_not be_blank
    end

  end
  
  describe "creation for check lists" do
    before(:each) do
      @place = make_place_with_geom
      @check_list = @place.check_list
      @check_list.should be_is_default
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
        @first_observation.places.should include @place
        @last_observation.places.should include @place
      end
      it "should set first observation to the first research grade observation added" do
        lt = without_delay { ListedTaxon.make!(:list => @check_list, :place => @place, :taxon => @taxon) }
        lt.first_observation.should eq @first_observation
      end
      it "should set last observation to the last research grade observation observed" do
        lt = without_delay { ListedTaxon.make!(:list => @check_list, :place => @place, :taxon => @taxon) }
        lt.last_observation.should eq @last_observation
      end
    end
    
    it "should make sure the user matches the check list user" do
      lt = @user_check_list.listed_taxa.build(:taxon => Taxon.make!, :user => @user)
      lt.should be_valid
      lt = @user_check_list.listed_taxa.build(:taxon => Taxon.make!, :user => User.make!)
      lt.should_not be_valid
    end
    
    it "should allow curators to add to owned check lists" do
      lt = @user_check_list.listed_taxa.build(:taxon => Taxon.make!, :user => make_curator)
      lt.should be_valid
    end
    
    it "should inherit the check list's source" do
      lt = @user_check_list.listed_taxa.create(:taxon => Taxon.make!, :user => @user)
      lt.source_id.should be(@user_check_list.source_id)
    end

    it "should set establishment_means to native if there is a native listing for a child place" do
      child_place = Place.make!(:parent => @place)
      t = Taxon.make!
      child_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::NATIVE)
      lt = @check_list.add_taxon(t)
      lt.establishment_means.should eq(ListedTaxon::NATIVE)
    end

    it "should set establishment_means to introduced if there is a introduced listing for a parent place" do
      parent_place = Place.make!
      place = Place.make!(:parent => parent_place)
      t = Taxon.make!
      parent_place.check_list.add_taxon(t, :establishment_means => ListedTaxon::INTRODUCED)
      lt = place.check_list.add_taxon(t)
      lt.establishment_means.should eq(ListedTaxon::INTRODUCED)
    end
  end
  
  describe "check list auto removal" do
    before(:each) do
      @place = Place.make!
      @check_list = @place.check_list
      @check_list.should be_is_default
    end
    
    it "should work for vanilla" do
      lt = ListedTaxon.make!(:list => @check_list)
      lt.should be_auto_removable_from_check_list
    end
    
    it "should not work if first observation" do
      lt = ListedTaxon.make!(:list => @check_list, :first_observation => Observation.make!)
      lt.should_not be_auto_removable_from_check_list
    end
    
    it "should not work if user" do
      lt = ListedTaxon.make!(:list => @check_list, :user => User.make!)
      lt.should_not be_auto_removable_from_check_list
    end
    
    it "should not work if taxon range" do
      lt = ListedTaxon.make!(:list => @check_list, :taxon_range => TaxonRange.make!)
      lt.should_not be_auto_removable_from_check_list
    end
    
    it "should not work if source" do
      lt = ListedTaxon.make!(:list => @check_list, :source => Source.make!)
      lt.should_not be_auto_removable_from_check_list
    end
  end
  
  describe "updating" do
    it "should set cache columns BEFORE validation" do
      lt = ListedTaxon.make!
      good_obs = Observation.make!(:user => lt.list.user, :taxon => lt.taxon)
      bad_obs = Observation.make!(:user => lt.list.user)
      lt.update_attributes(:first_observation => good_obs)
      lt.should be_valid
      ListedTaxon.where(id: lt.id).update_all(first_observation_id: bad_obs.id)
      lt.reload
      lt.should be_valid
      lt.first_observation_id.should == good_obs.id
    end
    
    it "should fail if occurrence_status set to absent and there is a confirming observation" do
      l = CheckList.make!
      t = Taxon.make!
      o = make_research_grade_observation(:latitude => l.place.latitude, :longitude => l.place.longitude, :taxon => t)
      lt = ListedTaxon.make!(:list => l, :taxon => t, :first_observation => o)
      lt.should be_valid
      lt.occurrence_status_level = ListedTaxon::ABSENT
      lt.should_not be_valid
      lt.errors[:occurrence_status_level].should_not be_blank
    end
  end
  
  describe "check list user removal" do
    before(:each) do
      @place = Place.make!
      @check_list = @place.check_list
      @check_list.should be_is_default
      @user = User.make!
    end
    
    it "should work for user who added" do
      lt = ListedTaxon.make!(:list => @check_list, :user => @user)
      lt.should be_removable_by @user
    end
    
    it "should work for lists the user owns" do
      list = List.make!(:user => @user)
      lt = ListedTaxon.make!(:list => list)
      lt.should be_removable_by @user
    end
    
    it "should not work if first observation" do
      lt = ListedTaxon.make!(:list => @check_list, :first_observation => Observation.make!)
      lt.should_not be_removable_by @user
    end
    
    it "should not work if remover is not user" do
      lt = ListedTaxon.make!(:list => @check_list, :user => User.make!)
      lt.should_not be_removable_by @user
    end
    
    it "should not work if taxon range" do
      lt = ListedTaxon.make!(:list => @check_list, :taxon_range => TaxonRange.make!)
      lt.should_not be_removable_by @user
    end
    
    it "should not work if source" do
      lt = ListedTaxon.make!(:list => @check_list, :source => Source.make!)
      lt.should_not be_removable_by @user
    end
    
    it "should work for admins" do
      lt = ListedTaxon.make!(:list => @check_list, :first_observation => Observation.make!)
      user = make_user_with_role(:admin)
      user.should be_admin
      lt.should be_removable_by user
    end
    
    it "should work if there's no source" do
      lt = ListedTaxon.make!(:list => @check_list)
      lt.citation_object.should be_blank
      lt.should be_removable_by @user
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
      ListedTaxon.find_by_id(@reject.id).should be_blank
    end
    
    it "should add comments from the reject to the keeper" do
      comment = Comment.make!(:parent => @reject)
      @keeper.comments.count.should be(0)
      @keeper.merge(@reject)
      @keeper.comments.count.should be(1)
    end
    
    it "should add attributes from the reject to the keeper" do
      @reject.update_attribute(:description, "this thing is dust")
      @keeper.merge(@reject)
      @keeper.description.should == "this thing is dust"
    end
    
    it "should not override attributes in the keeper" do
      @keeper.update_attribute(:description, "i will survive")
      @reject.update_attribute(:description, "i'm doomed!")
      @keeper.merge(@reject)
      @keeper.description.should == "i will survive"
    end
  end
  
  describe "merge_duplicates" do
    it "should keep the earliest listed taxon" do
      keeper = ListedTaxon.make!
      reject = ListedTaxon.make!(:list => keeper.list)
      ListedTaxon.where(id: reject.id).update_all(taxon_id: keeper.taxon_id)
      ListedTaxon.merge_duplicates
      ListedTaxon.find_by_id(keeper.id).should_not be_blank
      ListedTaxon.find_by_id(reject.id).should be_blank
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
      ListedTaxon.find_by_id(keeper.id).should_not be_blank
      rejects.each do |reject|
        ListedTaxon.find_by_id(reject.id).should be_blank
      end
    end
  end
  
  describe "cache_columns" do
    before(:each) do
      @place = Place.make!(:name => "foo to the bar")
      @place.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
      @check_list = @place.check_list
      @taxon = Taxon.make!(:rank => Taxon::SPECIES)
    end
    
    it "should set first observation to obs of desc taxa" do
      subspecies = Taxon.make!(:rank => Taxon::SUBSPECIES, :parent => @taxon)
      o = make_research_grade_observation(:taxon => subspecies, :latitude => @place.latitude, :longitude => @place.longitude)
      lt = ListedTaxon.make!(:list => @check_list, :place => @place, :taxon => @taxon)
      ListedTaxon.update_cache_columns_for(lt)
      lt.reload
      lt.first_observation_id.should == o.id
    end
  end
end

describe ListedTaxon, "validation for comprehensive check lists" do
  before(:each) do
    @parent = Taxon.make!
    @taxon = Taxon.make!(:parent => @parent)
    @place = Place.make!
    @check_list = CheckList.make!(:place => @place, :taxon => @parent, :comprehensive => true)
    @check_listed_taxon = @check_list.add_taxon(@taxon)
  end
  
  it "should fail if a comprehensive check list that doesn't contain this taxon exists for a parent taxon" do
    t = Taxon.make!(:parent => @parent)
    @check_list.taxon_ids.should_not include(t.id)
    lt = @place.check_list.add_taxon(t)
    lt.should_not be_valid
    lt.errors[:taxon_id].should_not be_blank
  end
  
  it "should fail if a comprehensive check list that doesn't contain this taxon exists for a parent taxon in an ancestor place" do
    t = Taxon.make!(:parent => @parent)
    @check_list.taxon_ids.should_not include(t.id)
    p = Place.make!(:parent => @place)
    lt = p.check_list.add_taxon(t)
    lt.should_not be_valid
    lt.errors[:taxon_id].should_not be_blank
  end
  
  it "should pass if a comprehensive check lists that does contain this taxon exists for a parent taxon" do
    t = Taxon.make!(:parent => @parent)
    clt = @check_list.add_taxon(t)
    @check_list.taxon_ids.should include(t.id)
    lt = @place.check_list.add_taxon(t)
    lt.should be_valid
  end
  
  it "should pass if a comprehensive check list that does't contain this taxon exists for a parent taxon and there is a confirming observation" do
    t = Taxon.make!(:parent => @parent)
    o = make_research_grade_observation(:taxon => t, :latitude => @place.latitude, :longitude => @place.longitude)
    @check_list.taxon_ids.should_not include(t.id)
    lt = @place.check_list.add_taxon(t, :first_observation => o)
    lt.should be_valid
  end
end

describe ListedTaxon, "establishment means propagation" do
  let(:parent) { Place.make! }
  let(:place) { Place.make!(:parent => parent) }
  let(:child) { Place.make!(:parent => place) }
  let(:taxon) { Taxon.make! }
  let(:parent_listed_taxon) { parent.check_list.add_taxon(taxon) }
  let(:place_listed_taxon) { place.check_list.add_taxon(taxon) }
  let(:child_listed_taxon) { child.check_list.add_taxon(taxon) }
  it "should bubble up for native" do
    parent_listed_taxon.establishment_means.should be_blank
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::NATIVE)
    parent_listed_taxon.reload
    parent_listed_taxon.establishment_means.should eq(place_listed_taxon.establishment_means)
  end

  it "should bubble up for endemic" do
    parent_listed_taxon.establishment_means.should be_blank
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::ENDEMIC)
    parent_listed_taxon.reload
    parent_listed_taxon.establishment_means.should eq(place_listed_taxon.establishment_means)
  end

  it "should not trickle down for native" do
    child_listed_taxon.establishment_means.should be_blank
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::NATIVE)
    child_listed_taxon.reload
    child_listed_taxon.establishment_means.should be_blank
  end

  it "should trickle down for introduced" do
    child_listed_taxon.establishment_means.should be_blank
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
    child_listed_taxon.reload
    child_listed_taxon.establishment_means.should eq(place_listed_taxon.establishment_means)
  end

  it "should not bubble up for introduced" do
    parent_listed_taxon.establishment_means.should be_blank
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
    parent_listed_taxon.reload
    parent_listed_taxon.establishment_means.should be_blank
  end

  it "should not alter previous settings" do
    parent_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::NATIVE)
    parent_listed_taxon.reload
    parent_listed_taxon.establishment_means.should eq(ListedTaxon::INTRODUCED)
  end

  it "should not alter est means of other taxa" do
    new_parent_listed_taxon = parent.check_list.add_taxon(Taxon.make!)
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::NATIVE)
    new_parent_listed_taxon.reload
    new_parent_listed_taxon.establishment_means.should be_blank
  end

  it "trickle down should be forceable" do
    child_listed_taxon.establishment_means.should be_blank
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
    child_listed_taxon.reload
    child_listed_taxon.establishment_means.should eq ListedTaxon::INTRODUCED
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::NATIVE)
    place_listed_taxon.trickle_down_establishment_means(:force => true)
    child_listed_taxon.reload
    child_listed_taxon.establishment_means.should eq ListedTaxon::NATIVE
  end

  it "trickle down should be forceable based on force_trickle_down_establishment_means" do
    child_listed_taxon.establishment_means.should be_blank
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
    child_listed_taxon.reload
    child_listed_taxon.establishment_means.should eq ListedTaxon::INTRODUCED
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::NATIVE, :force_trickle_down_establishment_means => true)
    child_listed_taxon.reload
    child_listed_taxon.establishment_means.should eq ListedTaxon::NATIVE
  end

  it "trickle should not update listed taxa for other places" do
    sibling_place = Place.make!(:parent => parent)
    sibling_lt = sibling_place.check_list.add_taxon(taxon, :establishment_means => ListedTaxon::NATIVE)
    sibling_lt.establishment_means.should eq ListedTaxon::NATIVE
    place_listed_taxon.update_attributes(:establishment_means => ListedTaxon::INTRODUCED)
    place_listed_taxon.trickle_down_establishment_means(:force => true)
    child_listed_taxon.reload
    child_listed_taxon.establishment_means.should eq ListedTaxon::INTRODUCED
    sibling_lt.reload
    sibling_lt.establishment_means.should eq ListedTaxon::NATIVE
  end
end


describe ListedTaxon, "cache column setting for check lists" do
  before do
    without_delay do
      @place = make_place_with_geom
      @check_list = @place.check_list
    end
  end
  it "should be queued" do
    lt = ListedTaxon.make!(:list => @check_list)
    Delayed::Job.where("handler LIKE '%ListedTaxon%update_cache_columns_for%\n- #{lt.id}\n'").exists?.should be true
  end

  it "should not be queued if there's an existing job" do
    lt = ListedTaxon.make!(:list => @check_list)
    Delayed::Job.where("handler LIKE '%ListedTaxon%update_cache_columns_for%\n- #{lt.id}\n'").count.should eq(1)
    lt.update_attributes(:establishment_means => ListedTaxon::NATIVE)
    Delayed::Job.where("handler LIKE '%ListedTaxon%update_cache_columns_for%\n- #{lt.id}\n'").count.should eq(1)
  end
end

describe ListedTaxon, "parent check list syncing" do
  before do
    without_delay do
      @parent = Place.make!
      @place = make_place_with_geom(:parent => @parent)
      @check_list = @place.check_list
    end
  end
  it "should be queued" do
    lt = ListedTaxon.make!(:list => @check_list)
    Delayed::Job.where("handler LIKE '%CheckList\n%id: ''#{@check_list.id}''\n%sync_with_parent%'").exists?.should be true
  end

  it "should not be queued if existing job" do
    lt = ListedTaxon.make!(:list => @check_list)
    Delayed::Job.where("handler LIKE '%CheckList\n%id: ''#{@check_list.id}''\n%sync_with_parent%'").count.should eq(1)
    lt2 = ListedTaxon.make!(:list => @check_list)
    Delayed::Job.where("handler LIKE '%CheckList\n%id: ''#{@check_list.id}''\n%sync_with_parent%'").count.should eq(1)
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
    @listed_taxon.update_attributes(:primary_listing => true)
    @listed_taxon.should_not be_primary_listing
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
    @listed_taxon.primary_listing.should be(true)
  end
  it "should set second lt as primary listing = false" do
    @listed_taxon_two.primary_listing.should be(false)
  end
  it "should override attributes (like establishment means) of the non-primary listed taxon" do
    @listed_taxon.primary_listing.should be(true)
    @listed_taxon.update_attribute(:establishment_means, "introduced")
    @listed_taxon_two.reload
    expect(@listed_taxon_two.establishment_means).to eq("introduced")
  end
  it "should reassign the primary to the second taxon when the original primary is destroyed" do
    @listed_taxon.primary_listing.should be(true)
    @listed_taxon.destroy
    @listed_taxon_two.reload
    @listed_taxon_two.primary_listing.should be(true)
    @listed_taxon_two.destroy
  end
  it "should set each lt appropriately on update" do
    @listed_taxon_two.update_attribute(:primary_listing, true)
    @listed_taxon_two.primary_listing.should be(true)
    @listed_taxon.reload
    @listed_taxon.primary_listing.should be(false)
  end
end

describe ListedTaxon, "force_update_cache_columns" do
  before do
    @place = make_place_with_geom
    @check_list = CheckList.make!(:place => @place)
    @lt = ListedTaxon.make!(:list => @check_list, :place => @place, :primary_listing => true)
    @observation = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @lt.taxon)
    Observation.in_place(@place).should include @observation
    ListedTaxon.where(id: @lt).update_all(
      first_observation_id: nil,
      last_observation_id: nil,
      observations_count: nil,
      observations_month_counts: nil)
    Delayed::Job.delete_all
    Delayed::Job.count.should eq 0
    @lt.reload
    @lt.last_observation_id.should be_nil
  end

  it "should queue a job to update cache columns when not set" do
    @lt.save 
    Delayed::Job.count.should eq 1
    @lt.reload
    @lt.last_observation_id.should be_nil
  end

  it "should not queue a job to update cache columns if a job already exists" do
    @lt.save 
    Delayed::Job.count.should eq 1
    @lt.reload
    @lt.save
    Delayed::Job.count.should eq 1
  end

  it "should not queue a job to update cache columns if set" do
    Delayed::Job.delete_all
    @lt.force_update_cache_columns = true
    @lt.save
    Delayed::Job.count.should eq 0
  end

  it "should force cache columns to be set" do
    Delayed::Job.delete_all
    @lt.force_update_cache_columns = true
    @lt.save
    @lt.last_observation_id.should eq @observation.id
  end
end
