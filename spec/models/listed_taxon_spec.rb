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

end
