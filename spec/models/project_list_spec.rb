require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectList do
  describe "creation" do
    it "should set defaults" do
      p = Project.make
      pl = p.project_list
      pl.should be_valid
      pl.title.should_not be_blank
      pl.description.should_not be_blank
    end
  end
end

describe ProjectList, "refresh_with_observation" do
  it "should remove taxa with no more confirming observations" do
    p = Project.make
    pl = p.project_list
    t1 = Taxon.make
    t2 = Taxon.make
    o = Observation.make(:taxon => t1)
    pu = ProjectUser.make(:user => o.user, :project => p)
    po = ProjectObservation.make(:project => p, :observation => o)
    ProjectList.refresh_with_observation(o)
    pl.reload
    pl.taxon_ids.should include(o.taxon_id)
    
    o.update_attributes(:taxon => t2)
    ProjectList.refresh_with_observation(o, :taxon_id => o.taxon_id, 
      :taxon_id_was => t1.id, :user_id => o.user_id, :created_at => o.created_at)
    
    pl.reload
    pl.taxon_ids.should_not include(t1.id)
    pl.taxon_ids.should include(t2.id)
  end
end

