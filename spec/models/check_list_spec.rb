require File.dirname(__FILE__) + '/../spec_helper.rb'

describe CheckList do
  
  before(:each) do
    @check_list = CheckList.make(:taxon => Taxon.make)
  end
  
  it "should have one and only place" do
    @check_list.place = nil
    @check_list.should_not be_valid
  end
  
  it "should completable" do
    @check_list.respond_to?(:comprehensive).should be_true
  end
  
  it "should have a unique taxon for its place" do
    @new_check_list = CheckList.new(:place => @check_list.place, 
      :taxon => @check_list.taxon)
    @new_check_list.should_not be_valid
  end
  
  it "should create a new is_taxon? rule if taxon_id has been set" do
    @check_list.rules.should_not be_empty
  end
end

describe CheckList, "refresh_with_observation" do
  
  before(:all) do
    @worker = Delayed::Worker.new(:quiet => true)
    @worker.work_off
  end
  
  before(:each) do
    @place = Place.make(:name => "foo to the bar")
    @place.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
    @check_list = @place.check_list
    @taxon = Taxon.make(:rank => Taxon::SPECIES)
  end
  
  it "should update last observation" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude)
    t = o.taxon
    lt = @check_list.add_taxon(t)
    CheckList.refresh_with_observation(o)
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.last_observation_id.should be(o.id)
  end
  
  it "should update first observation" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude)
    t = o.taxon
    @check_list.add_taxon(t)
    CheckList.refresh_with_observation(o)
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.first_observation_id.should be(o.id)
  end
  
  it "should update observations count" do
    t = Taxon.make(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => t)
    lt = @check_list.add_taxon(t)
    lt.observations_count.should be(0)
    CheckList.refresh_with_observation(o)
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.observations_count.should be(1)
  end
  
  it "should update observations month counts" do
    t = Taxon.make(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(
      :latitude => @place.latitude, :longitude => @place.longitude, 
      :taxon => t, :observed_on_string => "2011-10-01")
    lt = @check_list.add_taxon(t)
    lt.observations_count.should be(0)
    CheckList.refresh_with_observation(o)
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.observation_month_stats['10'].should be(1)
  end
  
  it "should add listed taxa" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    @check_list.taxon_ids.should_not include(@taxon.id)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(@taxon.id)
  end
  
  it "should not add listed taxa for casual observations" do
    o = Observation.make(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    @check_list.taxon_ids.should_not include(@taxon.id)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should remove listed taxa if observation deleted" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    
    @place.place_geometry.geom.should_not be_blank
    o.geom.should_not be_blank
    
    @check_list.add_taxon(@taxon)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(@taxon.id)
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation(observation_id, :taxon_id => @taxon.id)
    @check_list.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should remove listed taxa if observation deleted" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    
    @place.place_geometry.geom.should_not be_blank
    o.geom.should_not be_blank
    
    @check_list.add_taxon(@taxon)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(@taxon.id)
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation(observation_id, :taxon_id => @taxon.id)
    @check_list.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should remove listed taxa if observation taxon id changed" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    
    lt = @check_list.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.should_not be_auto_removable_from_check_list
    
    o.taxon = Taxon.make
    o.save
    CheckList.refresh_with_observation(o, :taxon_id => o.taxon_id, :taxon_id_was => @taxon.id)
    @check_list.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should remove listed taxa if observation taxon id removed"
  
  it "should not remove listed taxa if added by a user" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    @check_list.add_taxon(@taxon, :user => User.make)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(@taxon.id)
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation(observation_id, :taxon_id => @taxon.id)
    @check_list.reload
    @check_list.taxon_ids.should include(@taxon.id)
  end
  
  it "should not add to a non-default list" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    l = CheckList.make(:place => @check_list.place)
    CheckList.refresh_with_observation(o)
    l.reload
    l.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should not remove listed taxa if non-default list" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    l = CheckList.make(:place => @check_list.place)
    l.add_taxon(@taxon)
    l.reload
    l.taxon_ids.should include(@taxon.id)
    CheckList.refresh_with_observation(o)
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation(observation_id, :taxon_id => @taxon.id)
    l.reload
    l.taxon_ids.should include(@taxon.id)
  end
  
  it "should remove taxa from ancestor lists"
  
  it "should use private coordinates" do
    g = @place.place_geometry.geom
    obscured_lat = g.envelope.lower_corner.y - 1
    obscured_lon = g.envelope.lower_corner.x - 1
    
    # make sure obscured coords lie outside the place geom
    PlaceGeometry.all(
      :conditions => "ST_Intersects(place_geometries.geom, ST_Point(#{obscured_lon}, #{obscured_lat}))").
      map(&:place_id).should_not include(@check_list.place_id)
      
    o = make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon, :geoprivacy => Observation::OBSCURED)
    Observation.update_all(
      ["latitude = ?, longitude = ?, geom = St_Point(#{obscured_lon}, #{obscured_lat})", 
        obscured_lat, obscured_lon], 
      ["id = ?", o.id])
    o.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    
    @check_list.taxon_ids.should include(@taxon.id)
  end
  
  it "should update old listed taxa which this observation confirmed" do
    other_place = Place.make(:name => "other place")
    other_place.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))"))
    o = make_research_grade_observation(:latitude => other_place.latitude, 
      :longitude => other_place.longitude, :taxon => @taxon)
    CheckList.refresh_with_observation(o)
    lt = other_place.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.last_observation_id.should be(o.id)
    
    o.update_attributes(:latitude => @place.latitude, :longitude => @place.longitude)
    CheckList.refresh_with_observation(o)
    lt = @check_list.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.last_observation_id.should be(o.id)
    
    other_place.listed_taxa.find_by_taxon_id(@taxon.id).should be_blank
  end
  
  it "should update old listed taxa when obs coordinates change" do
    make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon)
    # it's the middle one, see?
    o = make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon)
    make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon)
    CheckList.refresh_with_observation(o)
    lt = @place.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.first_observation_id.should_not be(o.id)
    lt.observations_count.should be(3)
    
    o.update_attributes(:latitude => 0, :longitude => 0)
    CheckList.refresh_with_observation(o, :latitude_was => @place.latitude, 
      :longitude_was => @place.longitude)
    lt = @check_list.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.should_not be_blank
    lt.observations_count.should be(2)
  end
  
  it "should update old listed taxa when taxon changes" do
    make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon, :observed_on_string => "1 week ago")
    # it's the middle one, see?
    o = make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon, :observed_on_string => "3 days ago")
    make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon, :observed_on_string => "yesterday")
    CheckList.refresh_with_observation(o)
    lt = @place.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.last_observation_id.should_not be(o.id)
    lt.observations_count.should be(3)
    
    o.update_attributes(:taxon => Taxon.make)
    CheckList.refresh_with_observation(o, :taxon_id_was => @taxon.id)
    lt = @check_list.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.should_not be_blank
    lt.observations_count.should be(2)
  end
  
  it "should not remove taxa just because obs obscured" do
    p = Place.make
    p.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0)))"))
    o = make_research_grade_observation(:latitude => p.latitude, :longitude => p.longitude)
    CheckList.refresh_with_observation(o)
    p.check_list.taxon_ids.should include(o.taxon_id)
    o.update_attributes(:geoprivacy => Observation::OBSCURED)
    CheckList.refresh_with_observation(o, :latitude_was => p.latitude, :longitude_was => p.longitude)
    p.reload
    p.check_list.taxon_ids.should include(o.taxon_id)
  end
  
  it "should not remove taxa for new observations" do
    t = Taxon.make(:species)
    lt = @check_list.add_taxon(t)
    lt.should be_auto_removable_from_check_list
    o = Observation.make(:taxon => t, :latitude => @place.latitude, :longitude => @place.longitude)
    CheckList.refresh_with_observation(o, :new => true)
    @check_list.reload
    @check_list.taxon_ids.should include(o.taxon_id)
  end
  
  it "should add new taxa even if ancestors have already been added to this place" do
    parent = Taxon.make(:rank => Taxon::GENUS)
    child = Taxon.make(:rank => Taxon::SPECIES, :parent => parent)
    @place.check_list.add_taxon(parent)
    @place.taxon_ids.should include(parent.id)
    
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => child)
    CheckList.refresh_with_observation(o)
    @place.reload
    @place.taxon_ids.should include(child.id)
  end
  
  it "should add the species along with infraspecies" do
    species = Taxon.make(:rank => Taxon::SPECIES)
    subspecies = Taxon.make(:rank => Taxon::SUBSPECIES, :parent => species)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => subspecies)
    CheckList.refresh_with_observation(o)
    @place.reload
    @place.taxon_ids.should include(species.id)
  end
end

describe CheckList, "sync_with_parent" do
  it "should add taxa to the parent" do
    parent_place = Place.make
    parent_list = parent_place.check_list
    place = Place.make(:parent => parent_place)
    list = place.check_list
    taxon = Taxon.make
    
    list.add_taxon(taxon.id)
    list.taxon_ids.should include(taxon.id)
    list.sync_with_parent
    parent_list.reload
    parent_list.taxon_ids.should include(taxon.id)
  end
end

describe CheckList, "updating to comprehensive" do
  before(:each) do
    @parent = Taxon.make
    @taxon = Taxon.make(:parent => @parent)
    @place = Place.make
  end
  
  it "should mark listed taxa of descendant taxa from other check lists for this place as absent" do
    lt = @place.check_list.add_taxon(@taxon)
    lt.should_not be_absent
    
    l = CheckList.make(:place => @place, :taxon => @parent, :comprehensive => true)
    lt.reload
    lt.should be_absent
  end
  
  it "should mark listed taxa of descendant taxa from other check lists for this place as absent if they are on this list" do
    l = CheckList.make(:place => @place, :taxon => @parent)
    l.add_taxon(@taxon)
    l.taxon_ids.should include(@taxon.id)
    
    lt = @place.check_list.add_taxon(@taxon)
    @place.check_list.taxon_ids.should include(@taxon.id)
    lt.should_not be_absent
    
    l.update_attributes(:comprehensive => true)
    lt.reload
    lt.should_not be_absent
  end
end
