require File.dirname(__FILE__) + '/../spec_helper.rb'

describe ProjectList do
  describe "creation" do
    it "should set defaults" do
      p = Project.make!
      pl = p.project_list
      pl.should be_valid
      pl.title.should_not be_blank
      pl.description.should_not be_blank
    end
  end
end

describe ProjectList, "refresh_with_observation" do
  before { enable_elastic_indexing(Observation) }
  after { disable_elastic_indexing(Observation) }
  it "should remove taxa with no more confirming observations" do
    p = Project.make!
    pl = p.project_list
    t1 = Taxon.make!
    t2 = Taxon.make!
    o = make_research_grade_observation(:taxon => t1)
    
    pu = ProjectUser.make!(:user => o.user, :project => p)
    po = ProjectObservation.make!(:project => p, :observation => o, :user => o.user)
    ProjectList.refresh_with_observation(o)
    pl.reload
    pl.taxon_ids.should include(o.taxon_id) #
    
    o.update_attributes(:taxon => t2)
    i = Identification.make!(:observation => o, :taxon => t2)
    Observation.set_quality_grade(o.id)
    o.reload
    
    ProjectList.refresh_with_observation(o, :taxon_id => o.taxon_id, 
      :taxon_id_was => t1.id, :user_id => o.user_id, :created_at => o.created_at)
    pl.reload
    pl.taxon_ids.should_not include(t1.id)
    pl.taxon_ids.should include(t2.id)
  end
  
  it "should add taxa from research grade observations added to the project" do
    p = Project.make!
    pl = p.project_list
    t1 = Taxon.make!
    o = make_research_grade_observation(:taxon => t1)
    pu = ProjectUser.make!(:user => o.user, :project => p)
    po = without_delay { ProjectObservation.make!(:project => p, :observation => o) }
    pl.reload
    pl.taxon_ids.should include(o.taxon_id) #
  end
  
  it "should add taxa from project observations that become research grade" do
    p = Project.make!
    pl = p.project_list
    t1 = Taxon.make!
    options = {
      :taxon => t1, :latitude => 1, :longitude => 1, :observed_on_string => "yesterday"
    }
    o = without_delay { Observation.make!(options) } #casual obs
    pu = ProjectUser.make!(:user => o.user, :project => p)
    po = without_delay { ProjectObservation.make!(:project => p, :observation => o) }
    pl.reload
    pl.taxon_ids.should_not include(o.taxon_id) #
    
    o.photos << LocalPhoto.make!(:user => o.user)
    i = without_delay { Identification.make!(:observation => o, :taxon => o.taxon) } #make obs rg
    pl.reload
    pl.taxon_ids.should include(o.taxon_id) #
  end
  
  it "should give curator_identification precedence" do
    p = Project.make!
    pl = p.project_list
    t1 = Taxon.make!
    t2 = Taxon.make!
    o = make_research_grade_observation(:taxon => t1)
    
    pu = ProjectUser.make!(:user => o.user, :project => p)
    po = ProjectObservation.make!(:project => p, :observation => o)
    ProjectList.refresh_with_observation(o)
    pl.reload
    pl.taxon_ids.should include(o.taxon_id) #
    
    pu2 = ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR) 
    i = without_delay { Identification.make!(:observation => o, :taxon => t2, :user => pu2.user) }
    pl.reload
    pl.taxon_ids.should_not include(t1.id)
    pl.taxon_ids.should include(t2.id)
  end
  
  it "should add taxa to project list from project observations made by curators" do
    p = Project.make!
    pu = without_delay {ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR)}
    t = Taxon.make!
    o = Observation.make!(:user => pu.user, :taxon => t)
    po = without_delay {make_project_observation(:observation => o, :project => p, :user => o.user)}
    
    po.curator_identification_id.should eq(o.owners_identification.id)
    cid_taxon_id = Identification.find_by_id(po.curator_identification_id).taxon_id
    pl = p.project_list
    pl.taxon_ids.should include(cid_taxon_id)  
  end
  
  it "should confirm a species when a subspecies was observed" do
    species = Taxon.make!(:rank => "species")
    subspecies = Taxon.make!(:rank => "subspecies", :parent => species)
    p = Project.make!
    pl = p.project_list
    lt = pl.add_taxon(species, :user => p.user, :manually_added => true)
    po = make_project_observation_from_research_quality_observation(:project => p, :taxon => subspecies)
    Delayed::Worker.new(:quiet => true).work_off
    lt.reload
    lt.last_observation.should eq(po.observation)
  end
  
  it "should add taxa observed by project curators on reload" do
    p = Project.make!
    pu = without_delay {ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR)}
    t = Taxon.make!
    o = Observation.make!(:user => pu.user, :taxon => t)
    po = without_delay {make_project_observation(:observation => o, :project => p, :user => o.user)}
    
    po.curator_identification_id.should eq(o.owners_identification.id)
    cid_taxon_id = Identification.find_by_id(po.curator_identification_id).taxon_id
    pl = p.project_list
    pl.taxon_ids.should include(cid_taxon_id)
    lt = ListedTaxon.where(:list_id => pl.id, :taxon_id => cid_taxon_id).first
    lt.destroy
    pl.taxon_ids.should_not include(cid_taxon_id)
    LifeList.reload_from_observations(pl)
    pl.taxon_ids.should include(cid_taxon_id)
  end
end

describe ProjectList, "reload_from_observations" do
  before(:each) { enable_elastic_indexing( Observation ) }
  after(:each) { disable_elastic_indexing( Observation ) }
  it "should not delete manually added taxa when descendant taxa have been observed" do
    p = Project.make!
    pl = p.project_list
    species = Taxon.make!(:rank => "species")
    subspecies = Taxon.make!(:rank => "subspecies", :parent => species)
    lt = pl.add_taxon(species, :manually_added => true, :user => p.user)
    po = make_project_observation(:project => p, :taxon => subspecies)
    Delayed::Worker.new(:quiet => true).work_off
    ProjectList.reload_from_observations(pl)
    ListedTaxon.find_by_id(lt.id).should_not be_blank
  end
end
