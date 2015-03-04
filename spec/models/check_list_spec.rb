require File.dirname(__FILE__) + '/../spec_helper.rb'

describe CheckList do
  
  before(:each) do
    @check_list = CheckList.make!(:taxon => Taxon.make!)
  end
  
  it "should have one and only place" do
    @check_list.place = nil
    @check_list.should_not be_valid
  end
  
  it "should completable" do
    expect(@check_list).to respond_to(:comprehensive)
  end
  
  it "should have a unique taxon for its place" do
    @new_check_list = CheckList.new(:place => @check_list.place, 
      :taxon => @check_list.taxon)
    @new_check_list.should_not be_valid
  end
  
  it "should create a new in_taxon? rule if taxon_id has been set" do
    @check_list.rules.should_not be_empty
  end

  it "should replace an is_taxon? rule if taxon_id changed" do
    t = Taxon.make!
    cl = CheckList.make!(:taxon => t)
    cl.rules.detect{|r| r.operator == "in_taxon?"}.operand.should eq(t)
    t2 = Taxon.make!
    cl.update_attributes(:taxon => t2)
    cl.reload
    cl.rules.detect{|r| r.operator == "in_taxon?"}.operand.should eq(cl.taxon)
  end

  it "should remove the old is_taxon? rule if taxon_id changed" do
    r = @check_list.rules.first
    @check_list.update_attributes(:taxon => Taxon.make!)
    ListRule.find_by_id(r.id).should be_blank
  end

  it "should remove the old is_taxon? rule if the taxon_id was removed" do
    r = @check_list.rules.first
    @check_list.update_attributes(:taxon => nil)
    ListRule.find_by_id(r.id).should be_blank
    @check_list.reload
    @check_list.rules.should be_blank
  end
end

describe CheckList, "refresh_with_observation" do
  
  before(:all) do
    @worker = Delayed::Worker.new(:quiet => true)
    @worker.work_off
  end
  
  before(:each) do
    @place = Place.make(:name => "foo to the bar")
    @place.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
    @check_list = @place.check_list
    @taxon = Taxon.make!(:rank => Taxon::SPECIES)
  end
  
  it "should update last observation" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude)
    t = o.taxon
    lt = @check_list.add_taxon(t)
    without_delay { CheckList.refresh_with_observation(o) }
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.last_observation_id.should be(o.id)
  end
  
  it "should update first observation" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude)
    t = o.taxon
    @check_list.add_taxon(t)
    without_delay { CheckList.refresh_with_observation(o) }
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.first_observation_id.should be(o.id)
  end
  
  it "should update observations count" do
    t = Taxon.make!(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => t)
    lt = @check_list.add_taxon(t)
    lt.observations_count.should be(0)
    without_delay { CheckList.refresh_with_observation(o) }
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.observations_count.should be(1)
  end
  
  it "should update observations month counts" do
    t = Taxon.make!(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(
      :latitude => @place.latitude, :longitude => @place.longitude, 
      :taxon => t, :observed_on_string => "2011-10-01")
    lt = @check_list.add_taxon(t)
    lt.observations_count.should be(0)
    without_delay { CheckList.refresh_with_observation(o) }
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

  it "should not add duplicate listed taxa" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    @check_list.add_taxon(@taxon)
    @check_list.taxon_ids.should include(@taxon.id)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.listed_taxa.where(:taxon_id => o.taxon_id).size.should eq(1)
  end
  
  it "should not add listed taxa for casual observations" do
    o = Observation.make!(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
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
    without_delay { CheckList.refresh_with_observation(o) }
    @check_list.reload
    @check_list.taxon_ids.should include(@taxon.id)
    observation_id = o.id
    o.destroy
    without_delay { CheckList.refresh_with_observation(observation_id, :taxon_id => @taxon.id) }
    @check_list.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should remove listed taxa if observation taxon id changed" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    without_delay { CheckList.refresh_with_observation(o) }
    @check_list.reload
    
    lt = @check_list.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.should_not be_auto_removable_from_check_list
    
    o.taxon = Taxon.make!
    o.save
    without_delay { CheckList.refresh_with_observation(o, :taxon_id => o.taxon_id, :taxon_id_was => @taxon.id) }
    @check_list.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should remove listed taxa if observation taxon id removed"
  
  it "should not remove listed taxa if added by a user" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    @check_list.add_taxon(@taxon, :user => User.make!)
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
    l = CheckList.make!(:place => @check_list.place)
    CheckList.refresh_with_observation(o)
    l.reload
    l.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should not remove listed taxa if non-default list" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    l = CheckList.make!(:place => @check_list.place)
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
    p = make_place_with_geom(:wkt => "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0)))")
    l = p.check_list
    g = p.place_geometry.geom
    obscured_lat = g.envelope.lower_corner.y - 1
    obscured_lon = g.envelope.lower_corner.x - 1
    # make sure obscured coords lie outside the place geom
    PlaceGeometry.where("ST_Intersects(place_geometries.geom, ST_Point(#{obscured_lon}, #{obscured_lat}))").
      map(&:place_id).should_not include(p.id)
    o = make_research_grade_observation(:latitude => p.latitude, 
      :longitude => p.longitude, :taxon => @taxon, :geoprivacy => Observation::OBSCURED)
    Observation.where(id: o.id).update_all(
      ["latitude = ?, longitude = ?, geom = St_Point(#{obscured_lon}, #{obscured_lat})",
        obscured_lat, obscured_lon])
    o.reload
    PlaceGeometry.where("ST_Intersects(place_geometries.geom, ST_Point(#{o.private_longitude}, #{o.private_latitude}))").
      map(&:place_id).should include(p.id)
    l.taxon_ids.should_not include(@taxon.id)
    CheckList.refresh_with_observation(o)
    l.reload
    l.taxon_ids.should include(@taxon.id)
  end

  it "should respect the public positional accuracy" do
    p = make_place_with_geom(:wkt => "MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0)))")
    l = p.check_list
    g = p.place_geometry.geom
    obscured_lat = g.envelope.lower_corner.y - 1
    obscured_lon = g.envelope.lower_corner.x - 1
    # make sure obscured coords lie outside the place geom
    PlaceGeometry.where("ST_Intersects(place_geometries.geom, ST_Point(#{obscured_lon}, #{obscured_lat}))").
      map(&:place_id).should_not include(p.id)
    o = make_research_grade_observation(:latitude => p.latitude, 
      :longitude => p.longitude, :taxon => @taxon, :geoprivacy => Observation::OBSCURED)
    Observation.where(id: o.id).update_all(
      ["latitude = ?, longitude = ?, geom = St_Point(#{obscured_lon}, #{obscured_lat})",
        obscured_lat, obscured_lon])
    o.reload
    PlaceGeometry.where("ST_Intersects(place_geometries.geom, ST_Point(#{o.private_longitude}, #{o.private_latitude}))").
      map(&:place_id).should include(p.id)
    l.taxon_ids.should_not include(@taxon.id)
    CheckList.refresh_with_observation(o)
    l.reload
    l.taxon_ids.should_not include(@taxon.id)
  end
  
  it "should update old listed taxa which this observation confirmed" do
    other_place = Place.make!(:name => "other place")
    other_place.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))"))
    o = make_research_grade_observation(:latitude => other_place.latitude, 
      :longitude => other_place.longitude, :taxon => @taxon)
    without_delay { CheckList.refresh_with_observation(o) }
    lt = other_place.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.last_observation_id.should be(o.id)
    
    o.update_attributes(:latitude => @place.latitude, :longitude => @place.longitude)
    without_delay { CheckList.refresh_with_observation(o) }
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
    without_delay { CheckList.refresh_with_observation(o) }
    lt = @place.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.first_observation_id.should_not be(o.id)
    lt.observations_count.should be(3)
    
    o.update_attributes(:latitude => 0, :longitude => 0)
    without_delay do
      CheckList.refresh_with_observation(o, :latitude_was => @place.latitude, 
        :longitude_was => @place.longitude)
    end
    lt = @check_list.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.should_not be_blank
    lt.observations_count.should be(2)
  end
  
  it "should update old listed taxa when taxon changes" do
    o1 = make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon, :observed_on_string => "1 week ago")
    # it's the middle one, see?
    o2 = make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon, :observed_on_string => "3 days ago")
    o3 = make_research_grade_observation(:latitude => @place.latitude, 
      :longitude => @place.longitude, :taxon => @taxon, :observed_on_string => "yesterday")
    without_delay { CheckList.refresh_with_observation(o2) }
    lt = @place.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.last_observation_id.should_not be(o2.id)
    lt.observations_count.should eq 3
    
    o2.reload
    o2.update_attributes(:taxon => Taxon.make!)
    without_delay { CheckList.refresh_with_observation(o2, :taxon_id_was => @taxon.id) }
    lt = @check_list.listed_taxa.find_by_taxon_id(@taxon.id)
    lt.should_not be_blank
    lt.observations_count.should eq 2
  end
  
  it "should not remove taxa just because obs obscured" do
    p = Place.make!
    p.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0)))"))
    o = make_research_grade_observation(:latitude => p.latitude, :longitude => p.longitude)
    CheckList.refresh_with_observation(o)
    p.check_list.taxon_ids.should include(o.taxon_id)
    o.update_attributes(:geoprivacy => Observation::OBSCURED)
    CheckList.refresh_with_observation(o, :latitude_was => p.latitude, :longitude_was => p.longitude)
    p.reload
    p.check_list.taxon_ids.should include(o.taxon_id)
  end
  
  it "should not remove taxa for new observations" do
    t = Taxon.make!(:species)
    lt = @check_list.add_taxon(t)
    lt.should be_auto_removable_from_check_list
    o = Observation.make!(:taxon => t, :latitude => @place.latitude, :longitude => @place.longitude)
    CheckList.refresh_with_observation(o, :new => true)
    @check_list.reload
    @check_list.taxon_ids.should include(o.taxon_id)
  end
  
  it "should add new taxa even if ancestors have already been added to this place" do
    parent = Taxon.make!(:rank => Taxon::GENUS)
    child = Taxon.make!(:rank => Taxon::SPECIES, :parent => parent)
    @place.check_list.add_taxon(parent)
    @place.taxon_ids.should include(parent.id)
    
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => child)
    CheckList.refresh_with_observation(o)
    @place.reload
    @place.taxon_ids.should include(child.id)
  end
  
  it "should add the species along with infraspecies" do
    species = Taxon.make!(:rank => Taxon::SPECIES)
    subspecies = Taxon.make!(:rank => Taxon::SUBSPECIES, :parent => species)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => subspecies)
    CheckList.refresh_with_observation(o)
    @place.reload
    @place.taxon_ids.should include(species.id)
  end

  it "should queue unique jobs to refresh listed taxa" do
    t = Taxon.make!(:species)
    lt = @check_list.add_taxon(t)
    o = Observation.make!(:taxon => t, :latitude => @place.latitude, :longitude => @place.longitude)
    CheckList.refresh_with_observation(o, :new => true)
    # Delayed::Job.all.each {|j| puts j.handler; puts}
    Delayed::Job.where("handler LIKE '%CheckList%refresh_listed_taxon% #{lt.id}\n%'").count.should eq(1)
    CheckList.refresh_with_observation(o, :new => true)
    Delayed::Job.where("handler LIKE '%CheckList%refresh_listed_taxon% #{lt.id}\n%'").count.should eq(1)
  end
end

describe CheckList, "sync_with_parent" do
  it "should add taxa to the parent" do
    parent_place = Place.make!
    parent_list = parent_place.check_list
    place = Place.make!(:parent => parent_place)
    list = place.check_list
    taxon = Taxon.make!
    
    list.add_taxon(taxon.id)
    list.taxon_ids.should include(taxon.id)
    list.sync_with_parent
    parent_list.reload
    parent_list.taxon_ids.should include(taxon.id)
  end

  it "should work if parent doesn't have a check list" do
    parent = Place.make!(:prefers_check_lists => false)
    place = Place.make!(:parent => parent)
    list = place.check_list
    taxon = Taxon.make!
    list.add_taxon(taxon)
    expect{ list.sync_with_parent }.to_not raise_error
  end
end
