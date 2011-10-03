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
  
  it "should be editable by any user" do
    @check_list.should be_editable_by User.make
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
  
  before(:each) do
    @place = Place.make(:name => "foo to the bar")
    @place.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
    @check_list = @place.check_list
    @taxon = Taxon.make(:rank => Taxon::SPECIES)
  end
  
  it "should update last observation" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude)
    t = o.taxon
    @check_list.add_taxon(t)
    CheckList.refresh_with_observation(o)
    lt = @check_list.listed_taxa.find_by_taxon_id(t.id)
    lt.last_observation_id.should be(o.id)
  end
  
  it "should add listed taxa" do
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => @taxon)
    @check_list.taxon_ids.should_not include(@taxon.id)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(@taxon.id)
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
    Rails.logger.debug "[DEBUG] let's get this party started, observation_id = #{observation_id}"
    
    CheckList.refresh_with_observation(observation_id, :taxon_id => @taxon.id)
    @check_list.reload
    @check_list.taxon_ids.should_not include(@taxon.id)
  end
  
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
end
