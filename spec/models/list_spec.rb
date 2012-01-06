require File.dirname(__FILE__) + '/../spec_helper.rb'

describe List, "updating" do
  it "should not be allowed anyone other than the owner" do
    list = LifeList.make
    other_user = User.make
    list.should be_editable_by list.user
    list.should_not be_editable_by other_user
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

describe List, "refresh_with_observation" do
  before(:each) do
    @parent = Taxon.make
    @list = LifeList.make
    @list.build_taxon_rule(@parent)
    @list.save!
  end
  
  it "should add new taxa to the list" do
    t = Taxon.make(:parent => @parent)
    o = Observation.make(:user => @list.user, :taxon => t)
    @list.taxon_ids.should_not include(t.id)
    List.refresh_with_observation(o)
    @list.reload
    @list.taxon_ids.should include(t.id)
  end
  
  it "should remove listed taxa that weren't manually added" do
    t = Taxon.make(:parent => @parent)
    o = Observation.make(:user => @list.user, :taxon => t)
    @list.taxon_ids.should_not include(t.id)
    List.refresh_with_observation(o)
    @list.reload
    @list.taxon_ids.should include(t.id)
    
    o.destroy
    List.refresh_with_observation(o.id, :created_at => o.created_at, :taxon_id => o.taxon_id, :user_id => o.user_id)
    @list.reload
    @list.taxon_ids.should_not include(t.id)
  end
  
  it "should keep listed taxa that were manually added" do
    t = Taxon.make(:parent => @parent)
    @list.add_taxon(t, :manually_added => true)
    @list.reload
    @list.taxon_ids.should include(t.id)
    
    o = Observation.make(:user => @list.user, :taxon => t)
    List.refresh_with_observation(o)
    o.destroy
    List.refresh_with_observation(o.id, :created_at => o.created_at, :taxon_id => o.taxon_id, :user_id => o.user_id)
    @list.reload
    @list.taxon_ids.should include(t.id)
  end
  
  it "should keep listed taxa with observations" do
    t = Taxon.make(:parent => @parent)
    o1 = Observation.make(:user => @list.user, :taxon => t)
    o2 = Observation.make(:user => @list.user, :taxon => t)
    List.refresh_with_observation(o2)
    
    o2.destroy
    List.refresh_with_observation(o2.id, :created_at => o2.created_at, :taxon_id => o2.taxon_id, :user_id => o2.user_id)
    @list.reload
    @list.taxon_ids.should include(t.id)
  end
  
  it "should remove taxa when taxon changed" do
    t1 = Taxon.make(:parent => @parent)
    t2 = Taxon.make(:parent => @parent)
    o = Observation.make(:user => @list.user, :taxon => t1)
    List.refresh_with_observation(o)
    @list.taxon_ids.should include(t1.id)
    
    o.update_attribute(:taxon_id, t2.id)
    @list.user.observations.first(:conditions => {:taxon_id => t1.id}).should be_blank
    @list.user.observations.first(:conditions => {:taxon_id => t2.id}).should_not be_blank
    List.refresh_with_observation(o.id, :taxon_id_was => t1.id)
    @list.reload
    @list.taxon_ids.should include(t2.id)
    @list.taxon_ids.should_not include(t1.id)
  end
end
