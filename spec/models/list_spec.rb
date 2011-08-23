require File.dirname(__FILE__) + '/../spec_helper.rb'

describe List, "creation" do
  fixtures :users, :taxa
  before(:each) do
    @list = List.new(
      :user => User.first
    )
  end
  it "should return a new instance" do
    @list.save!
    @list.should_not be(nil)
    @list.new_record?.should be(false)
  end
end

describe List, "updating" do
  fixtures :users, :taxa, :lists
  it "should not be allowed anyone other than the owner" do
    lists(:quentin_life_list).editable_by?(users(:quentin)).should be_true
    lists(:quentin_life_list).editable_by?(users(:ted)).should be_false
  end
end

# Note: List#refresh is pretty thoroughly tested by the Observation 
# spec, so these will remain unimplemented.  I couldn't figure out how to
# test them without touching observations anyway (KMU 2008-12-5)
describe List, "refreshing" do
  it "should update all last_observations in the list"
  it "should destroy all invalid listed taxa"
  it "should restrict its updates to the taxa param passed in"
end

describe List, "taxon adding" do
  
  it "should return a ListedTaxon" do
    list = List.make
    taxon = Taxon.make
    list.add_taxon(taxon).should be_a(ListedTaxon)
  end
  
  it "should not create a new ListedTaxon if the taxon is already in the list" do
    listed_taxon = ListedTaxon.make
    list = listed_taxon.list
    taxon = listed_taxon.taxon
    new_listed_taxon = list.add_taxon(taxon)
    new_listed_taxon.should_not be_valid
  end
  
end

# describe List, "refresh_with_observation" do
#   it "should update existing last observation" do
#     user = User.make
#     list = List.make(:user => user)
#     listed_taxon = ListedTaxon.make(:list => list)
#     listed_taxon.last_observation.should be_blank
#     observation = Observation.make(:user => user, :taxon => listed_taxon.taxon)
#     List.refresh_with_observation(observation)
#     listed_taxon.reload
#     listed_taxon.last_observation_id.should be(observation.id)
#   end
#   
#   it "should not add a new taxon"
# end

