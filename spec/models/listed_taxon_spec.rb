require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ListedTaxon do
  it "should be invalid when check list fields set on a non-check list" do
    list = List.make
    check_list = CheckList.make
    listed_taxon = ListedTaxon.new(:list => list, :taxon => Taxon.make,
      :occurrence_status_level => ListedTaxon::OCCURRENCE_STATUS_LEVELS.keys.first)
    listed_taxon.should_not be_valid
    listed_taxon.list = check_list
    listed_taxon.should be_valid
  end
  
  describe "creation" do
    before(:each) do
      @taxon = Taxon.make
      @first_observation = Observation.make(:taxon => @taxon)
      @user = @first_observation.user
      @last_observation = Observation.make(:taxon => @taxon, :user => @user, :observed_on_string => 1.minute.ago.to_s)
      @list = @user.life_list
      @listed_taxon = ListedTaxon.make(:taxon => @taxon, :list => @list)
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
      @place = Place.make
      @check_list = @place.check_list
      @check_list.should be_is_default
      @user = User.make
      @user_check_list = @place.check_lists.create(:title => "Foo!", :user => @user, :source => Source.make)
    end
    
    it "should make sure the user matches the check list user" do
      lt = @user_check_list.listed_taxa.build(:taxon => Taxon.make, :user => @user)
      lt.should be_valid
      lt = @user_check_list.listed_taxa.build(:taxon => Taxon.make, :user => User.make)
      lt.should_not be_valid
    end
    
    it "should allow curators to add to owned check lists" do
      lt = @user_check_list.listed_taxa.build(:taxon => Taxon.make, :user => make_curator)
      lt.should be_valid
    end
    
    it "should inherit the check list's source" do
      lt = @user_check_list.listed_taxa.create(:taxon => Taxon.make, :user => @user)
      lt.source_id.should be(@user_check_list.source_id)
    end
  end
  
  describe "check list auto removal" do
    before(:each) do
      @place = Place.make
      @check_list = @place.check_list
      @check_list.should be_is_default
    end
    
    it "should work for vanilla" do
      lt = ListedTaxon.make(:list => @check_list)
      lt.should be_auto_removable_from_check_list
    end
    
    it "should not work if first observation" do
      lt = ListedTaxon.make(:list => @check_list, :first_observation => Observation.make)
      lt.should_not be_auto_removable_from_check_list
    end
    
    it "should not work if user" do
      lt = ListedTaxon.make(:list => @check_list, :user => User.make)
      lt.should_not be_auto_removable_from_check_list
    end
    
    it "should not work if taxon range" do
      lt = ListedTaxon.make(:list => @check_list, :taxon_range => TaxonRange.make)
      lt.should_not be_auto_removable_from_check_list
    end
    
    it "should not work if source" do
      lt = ListedTaxon.make(:list => @check_list, :source => Source.make)
      lt.should_not be_auto_removable_from_check_list
    end
  end
  
  describe "check list user removal" do
    before(:each) do
      @place = Place.make
      @check_list = @place.check_list
      @check_list.should be_is_default
      @user = User.make
    end
    
    it "should work for user who added" do
      lt = ListedTaxon.make(:list => @check_list, :user => @user)
      lt.should be_removable_by @user
    end
    
    it "should work for lists the user owns" do
      list = List.make(:user => @user)
      lt = ListedTaxon.make(:list => list)
      lt.should be_removable_by @user
    end
    
    it "should not work if first observation" do
      lt = ListedTaxon.make(:list => @check_list, :first_observation => Observation.make)
      lt.should_not be_removable_by @user
    end
    
    it "should not work if remover is not user" do
      lt = ListedTaxon.make(:list => @check_list, :user => User.make)
      lt.should_not be_removable_by @user
    end
    
    it "should not work if taxon range" do
      lt = ListedTaxon.make(:list => @check_list, :taxon_range => TaxonRange.make)
      lt.should_not be_removable_by @user
    end
    
    it "should not work if source" do
      lt = ListedTaxon.make(:list => @check_list, :source => Source.make)
      lt.should_not be_removable_by @user
    end
    
    it "should work for admins" do
      lt = ListedTaxon.make(:list => @check_list, :first_observation => Observation.make)
      user = make_user_with_role(:admin)
      user.should be_admin
      lt.should be_removable_by user
    end
    
    it "should work if there's no source" do
      lt = ListedTaxon.make(:list => @check_list)
      lt.citation_object.should be_blank
      lt.should be_removable_by @user
    end
  end
  
  describe "citation object" do
    it "should set occurrence_status to present if set"
  end
  
  describe "merge" do
    before(:each) do
      @keeper = ListedTaxon.make
      @reject = ListedTaxon.make
    end
    
    it "should destroy the reject" do
      @keeper.merge(@reject)
      ListedTaxon.find_by_id(@reject.id).should be_blank
    end
    
    it "should add comments from the reject to the keeper" do
      comment = Comment.make(:parent => @reject)
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
      keeper = ListedTaxon.make
      reject = ListedTaxon.make(:list => keeper.list)
      ListedTaxon.update_all("taxon_id = #{keeper.taxon_id}", "id = #{reject.id}")
      ListedTaxon.merge_duplicates
      ListedTaxon.find_by_id(keeper.id).should_not be_blank
      ListedTaxon.find_by_id(reject.id).should be_blank
    end
  end
  
  describe "cache_columns" do
    before(:each) do
      @place = Place.make(:name => "foo to the bar")
      @place.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
      @check_list = @place.check_list
      @taxon = Taxon.make(:rank => Taxon::SPECIES)
    end
    
    it "should set first observation to obs of desc taxa" do
      subspecies = Taxon.make(:rank => Taxon::SUBSPECIES, :parent => @taxon)
      o = make_research_grade_observation(:taxon => subspecies, :latitude => @place.latitude, :longitude => @place.longitude)
      lt = ListedTaxon.make(:list => @check_list, :place => @place, :taxon => @taxon)
      ListedTaxon.update_cache_columns_for(lt)
      lt.reload
      lt.first_observation_id.should == o.id
    end
  end
end
