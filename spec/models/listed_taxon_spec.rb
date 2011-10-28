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
  end
  
  describe "citation object" do
    it "should set occurrence_status to present if set"
  end

end
