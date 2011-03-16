require File.dirname(__FILE__) + '/../spec_helper.rb'

describe List, "reload_from_observations" do
  before(:each) do
    @taxon = Taxon.make
    @child = Taxon.make(:parent => @taxon)
    @list = make_life_list_for_taxon(@taxon)
    @list.should be_valid
  end
  
  it "should destroy listed taxa where the taxon doesn't match the observation taxon" do
    user = @list.user
    listed_taxon = make_listed_taxon_of_taxon(@child)
    obs = Observation.make(:user => user, :taxon => @child)
    List.refresh_for_user(user, :taxa => [obs.taxon], :skip_update => true)
    @list.reload
    @list.taxon_ids.should include(@child.id)
  
    new_child = Taxon.make(:parent => @taxon)
    obs.update_attributes(:taxon => new_child)
    @list.reload
    @list.taxon_ids.should_not include(new_child.id)
  
    LifeList.reload_from_observations(@list)
    @list.reload
    @list.taxon_ids.should_not include(@child.id)
  end
  
  def make_listed_taxon_of_taxon(taxon)
    listed_taxon = @list.add_taxon(taxon)
    listed_taxon.should be_valid
    @list.reload
    @list.taxon_ids.should include(taxon.id)
    listed_taxon
  end
end
