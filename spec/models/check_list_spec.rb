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
    t = Taxon.make(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => t)
    @check_list.taxon_ids.should_not include(t.id)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(t.id)
  end
  
  it "should remove listed taxa if observation deleted" do
    t = Taxon.make(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => t)
    
    @place.place_geometry.geom.should_not be_blank
    o.geom.should_not be_blank
    
    @check_list.add_taxon(t)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(t.id)
    observation_id = o.id
    o.destroy
    Rails.logger.debug "[DEBUG] let's get this party started, observation_id = #{observation_id}"
    
    CheckList.refresh_with_observation(observation_id, :taxon_id => t.id)
    @check_list.reload
    @check_list.taxon_ids.should_not include(t.id)
  end
  
  it "should not remove listed taxa if added by a user" do
    t = Taxon.make(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => t)
    @check_list.add_taxon(t, :user => User.make)
    CheckList.refresh_with_observation(o)
    @check_list.reload
    @check_list.taxon_ids.should include(t.id)
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation(observation_id, :taxon_id => t.id)
    @check_list.reload
    @check_list.taxon_ids.should include(t.id)
  end
  
  it "should not add to a non-default list" do
    t = Taxon.make(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => t)
    l = CheckList.make(:place => @check_list.place)
    CheckList.refresh_with_observation(o)
    l.reload
    l.taxon_ids.should_not include(t.id)
  end
  
  it "should not remove listed taxa if non-default list" do
    t = Taxon.make(:rank => Taxon::SPECIES)
    o = make_research_grade_observation(:latitude => @place.latitude, :longitude => @place.longitude, :taxon => t)
    l = CheckList.make(:place => @check_list.place)
    l.add_taxon(t)
    l.reload
    l.taxon_ids.should include(t.id)
    CheckList.refresh_with_observation(o)
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation(observation_id, :taxon_id => t.id)
    l.reload
    l.taxon_ids.should include(t.id)
  end
  
  it "should remove taxa from ancestor lists"
end
