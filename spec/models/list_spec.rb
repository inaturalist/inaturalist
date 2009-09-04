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
  fixtures :lists, :taxa, :listed_taxa, :users
  before(:each) do
    @new_list = List.new(:user => users(:aaron))
  end
  
  it "should return a ListedTaxon" do
    anna = Taxon.find_by_name('Calypte anna')
    @new_list.add_taxon(anna).should be_a(ListedTaxon)
  end
  
  it "should not create a new ListedTaxon if the taxon is already in the list" do
    quentin_life_list = lists(:quentin_life_list)
    quentin_life_list.taxa.should include(taxa(:Calypte_anna))
    lt = quentin_life_list.add_taxon(taxa(:Calypte_anna))
    # lt.should be_nil
    lt.should_not be_valid
  end
end
