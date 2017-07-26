require File.dirname( __FILE__ ) + '/../spec_helper.rb'

describe CheckList do
  
  before( :each ) do
    @check_list = CheckList.make!( taxon: Taxon.make! )
  end
  
  it "should have one and only place" do
    @check_list.place = nil
    expect( @check_list ).not_to be_valid
  end
  
  it "should completable" do
    expect( @check_list ).to respond_to( :comprehensive )
  end
  
  it "should have a unique taxon for its place" do
    @new_check_list = CheckList.new( place: @check_list.place, taxon: @check_list.taxon )
    expect( @new_check_list ).not_to be_valid
  end
  
  it "should create a new in_taxon? rule if taxon_id has been set" do
    expect( @check_list.rules ).not_to be_empty
  end

  it "should replace an is_taxon? rule if taxon_id changed" do
    t = Taxon.make!
    cl = CheckList.make!( taxon: t )
    expect( cl.rules.detect{|r| r.operator == "in_taxon?"}.operand ).to eq( t )
    t2 = Taxon.make!
    cl.update_attributes( taxon: t2 )
    cl.reload
    expect( cl.rules.detect{|r| r.operator == "in_taxon?"}.operand ).to eq( cl.taxon )
  end

  it "should remove the old is_taxon? rule if taxon_id changed" do
    r = @check_list.rules.first
    @check_list.update_attributes( taxon: Taxon.make! )
    expect( ListRule.find_by_id( r.id ) ).to be_blank
  end

  it "should remove the old is_taxon? rule if the taxon_id was removed" do
    r = @check_list.rules.first
    @check_list.update_attributes( taxon: nil )
    expect( ListRule.find_by_id( r.id ) ).to be_blank
    @check_list.reload
    expect( @check_list.rules ).to be_blank
  end
end

describe CheckList, "creation" do
  before( :each ) { enable_elastic_indexing( Observation, Place ) }
  after( :each ) { disable_elastic_indexing( Observation, Place ) }
  it "should populate with taxa from RG observations within place boundary" do
    obs = make_research_grade_observation( latitude: 0.5, longitude: 0.5 )
    place = Place.make!
    without_delay do
      place.save_geom( GeoRuby::SimpleFeatures::Geometry.from_ewkt( "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))" ) )
    end
    expect( place.check_list.taxa ).to include obs.taxon
  end
end

describe CheckList, "refresh_with_observation" do
  
  before( :all ) do
    DatabaseCleaner.clean_with( :truncation, except: %w[spatial_ref_sys] )
    @worker = Delayed::Worker.new( quiet: true )
    @worker.work_off
  end
  
  before( :each ) do
    enable_elastic_indexing( Observation, Place )
    @place = Place.make( name: "foo to the bar" )
    @place.save_geom(
      GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt(
        "MULTIPOLYGON( ((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679 )))"
      )
    )
    @check_list = @place.check_list
    @taxon = Taxon.make!( rank: Taxon::SPECIES )
  end
  after( :each ) { disable_elastic_indexing( Observation, Place ) }
  
  it "should update last observation" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude )
    t = o.taxon
    lt = @check_list.add_taxon( t )
    without_delay { CheckList.refresh_with_observation( o ) }
    lt = @check_list.listed_taxa.find_by_taxon_id( t.id )
    expect( lt.last_observation_id ).to be( o.id )
  end
  
  it "should update first observation" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude )
    t = o.taxon
    @check_list.add_taxon( t )
    without_delay { CheckList.refresh_with_observation( o ) }
    lt = @check_list.listed_taxa.find_by_taxon_id( t.id )
    expect( lt.first_observation_id ).to be( o.id )
  end
  
  it "should update observations count" do
    t = Taxon.make!( rank: Taxon::SPECIES )
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: t )
    lt = @check_list.add_taxon( t )
    expect( lt.observations_count ).to eq 0
    without_delay { CheckList.refresh_with_observation( o ) }
    lt = @check_list.listed_taxa.find_by_taxon_id( t.id )
    expect( lt.observations_count ).to eq 1
  end

  it "should add listed taxa" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
    expect( @check_list.taxon_ids ).not_to include @taxon.id
    CheckList.refresh_with_observation( o )
    @check_list.reload
    expect( @check_list.taxon_ids ).to include @taxon.id
  end

  it "should not add duplicate listed taxa" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
    @check_list.add_taxon( @taxon )
    expect( @check_list.taxon_ids ).to include @taxon.id
    CheckList.refresh_with_observation( o )
    @check_list.reload
    expect( @check_list.listed_taxa.where( taxon_id: o.taxon_id ).size ).to eq 1
  end
  
  it "should not add listed taxa for casual observations" do
    o = Observation.make!( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
    expect( @check_list.taxon_ids ).not_to include @taxon.id
    CheckList.refresh_with_observation( o )
    @check_list.reload
    expect( @check_list.taxon_ids ).not_to include @taxon.id
  end
  
  it "should remove listed taxa if observation taxon id changed" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
    without_delay { CheckList.refresh_with_observation( o ) }
    @check_list.reload
    
    lt = @check_list.listed_taxa.find_by_taxon_id( @taxon.id )
    expect( lt ).not_to be_auto_removable_from_check_list
    o = Observation.find( o.id )
    o.taxon = Taxon.make!
    o.save
    without_delay { CheckList.refresh_with_observation( o, :taxon_id => o.taxon_id, :taxon_id_was => @taxon.id ) }
    @check_list.reload
    expect( @check_list.taxon_ids ).not_to include( @taxon.id )
  end
  
  it "should remove listed taxa if observation taxon id removed"
  
  it "should not remove listed taxa if added by a user" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
    @check_list.add_taxon( @taxon, user: User.make! )
    CheckList.refresh_with_observation( o )
    @check_list.reload
    expect( @check_list.taxon_ids ).to include( @taxon.id )
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation( observation_id, :taxon_id => @taxon.id )
    @check_list.reload
    expect( @check_list.taxon_ids ).to include( @taxon.id )
  end
  
  it "should not add to a non-default list" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
    l = CheckList.make!( place: @check_list.place )
    CheckList.refresh_with_observation( o )
    l.reload
    expect( l.taxon_ids ).not_to include( @taxon.id )
  end
  
  it "should not remove listed taxa if non-default list" do
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
    l = CheckList.make!( place: @check_list.place )
    l.add_taxon( @taxon )
    l.reload
    expect( l.taxon_ids ).to include( @taxon.id )
    CheckList.refresh_with_observation( o )
    observation_id = o.id
    o.destroy
    CheckList.refresh_with_observation( observation_id, :taxon_id => @taxon.id )
    l.reload
    expect( l.taxon_ids ).to include( @taxon.id )
  end
  
  it "should remove taxa from ancestor lists"
  
  it "should use private coordinates" do
    p = make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 10,10 10,10 0,0 0 )))")
    l = p.check_list
    g = p.place_geometry.geom
    obscured_lat = g.envelope.lower_corner.y - 1
    obscured_lon = g.envelope.lower_corner.x - 1
    # make sure obscured coords lie outside the place geom
    expect(
      PlaceGeometry.
        where( "ST_Intersects( place_geometries.geom, ST_Point(#{obscured_lon}, #{obscured_lat} ))" ).
        map( &:place_id )
    ).not_to include( p.id )
    o = make_research_grade_observation(latitude: p.latitude, 
      longitude: p.longitude, taxon: @taxon, geoprivacy: Observation::OBSCURED)
    Observation.where( id: o.id ).update_all(
      ["latitude = ?, longitude = ?, geom = St_Point( #{obscured_lon}, #{obscured_lat} )",
        obscured_lat, obscured_lon])
    o.reload
    expect(
      PlaceGeometry.
        where( "ST_Intersects( place_geometries.geom, ST_Point(#{o.private_longitude}, #{o.private_latitude} ))" ).
        map( &:place_id )
    ).to include( p.id )
    expect( l.taxon_ids ).not_to include( @taxon.id )
    CheckList.refresh_with_observation( o )
    l.reload
    expect( l.taxon_ids ).to include( @taxon.id )
  end

  it "should respect the public positional accuracy" do
    p = make_place_with_geom( wkt: "MULTIPOLYGON( ((0 0,0 0.1,0.1 0.1,0.1 0,0 0 )))" )
    l = p.check_list
    g = p.place_geometry.geom
    o = make_research_grade_observation(
      latitude: p.latitude, 
      longitude: p.longitude,
      taxon: @taxon,
      geoprivacy: Observation::OBSCURED
    )
    o.reload
    # place should contain private coordinates
    expect(
      PlaceGeometry.
        where( "ST_Intersects( place_geometries.geom, ST_Point(#{o.private_longitude}, #{o.private_latitude} ))" ).
        map( &:place_id )
    ).to include( p.id )
    # place should not contain public accuracy circle
    expect(
      p.bbox_contains_lat_lng_acc?( o.private_latitude, o.private_longitude, o.public_positional_accuracy )
    ).to be false
    expect( l.taxon_ids ).not_to include( @taxon.id )
    CheckList.refresh_with_observation( o )
    l.reload
    expect( l.taxon_ids ).not_to include( @taxon.id )
  end
  
  it "should update old listed taxa which this observation confirmed" do
    other_place = Place.make!( name: "other place" )
    other_place.save_geom( GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0 )))"))
    o = make_research_grade_observation(latitude: other_place.latitude, 
      longitude: other_place.longitude, taxon: @taxon)
    without_delay { CheckList.refresh_with_observation( o ) }
    lt = other_place.listed_taxa.find_by_taxon_id( @taxon.id )
    expect( lt.last_observation_id ).to be( o.id )
    
    o.update_attributes( latitude: @place.latitude, longitude: @place.longitude )
    without_delay { CheckList.refresh_with_observation( o ) }
    lt = @check_list.listed_taxa.find_by_taxon_id( @taxon.id )
    expect( lt.last_observation_id ).to be( o.id )
    
    expect( other_place.listed_taxa.find_by_taxon_id( @taxon.id ) ).to be_blank
  end
  
  it "should update old listed taxa when obs coordinates change" do
    make_research_grade_observation(latitude: @place.latitude, 
      longitude: @place.longitude, taxon: @taxon)
    # it's the middle one, see?
    o = make_research_grade_observation(latitude: @place.latitude, 
      longitude: @place.longitude, taxon: @taxon)
    make_research_grade_observation(latitude: @place.latitude, 
      longitude: @place.longitude, taxon: @taxon)
    without_delay { CheckList.refresh_with_observation( o ) }
    lt = @place.listed_taxa.find_by_taxon_id( @taxon.id )
    expect( lt.first_observation_id ).not_to be( o.id )
    expect( lt.observations_count ).to be( 3 )
    
    o.update_attributes( latitude: 0, longitude: 0 )
    without_delay do
      CheckList.refresh_with_observation(o, :latitude_was => @place.latitude, 
        :longitude_was => @place.longitude)
    end
    lt = @check_list.listed_taxa.find_by_taxon_id( @taxon.id )
    expect( lt ).not_to be_blank
    expect( lt.observations_count ).to be( 2 )
  end
  
  it "should update old listed taxa when taxon changes" do
    o1 = make_research_grade_observation(latitude: @place.latitude, 
      longitude: @place.longitude, taxon: @taxon, :observed_on_string => "1 week ago")
    # it's the middle one, see?
    o2 = make_research_grade_observation(latitude: @place.latitude, 
      longitude: @place.longitude, taxon: @taxon, :observed_on_string => "3 days ago")
    o3 = make_research_grade_observation(latitude: @place.latitude, 
      longitude: @place.longitude, taxon: @taxon, :observed_on_string => "yesterday")
    without_delay { CheckList.refresh_with_observation( o2 ) }
    lt = @place.listed_taxa.find_by_taxon_id( @taxon.id )
    expect( lt.last_observation_id ).not_to be( o2.id )
    expect( lt.observations_count ).to eq 3
    
    o2 = Observation.find( o2.id )
    o2.update_attributes( taxon: Taxon.make! )
    without_delay { CheckList.refresh_with_observation( o2, :taxon_id_was => @taxon.id ) }
    lt = @check_list.listed_taxa.find_by_taxon_id( @taxon.id )
    expect( lt ).not_to be_blank
    expect( lt.observations_count ).to eq 2
  end
  
  it "should not remove taxa just because obs obscured" do
    p = Place.make!
    p.save_geom( GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0 )))"))
    o = make_research_grade_observation( latitude: p.latitude, longitude: p.longitude )
    CheckList.refresh_with_observation( o )
    expect( p.check_list.taxon_ids ).to include( o.taxon_id )
    o.update_attributes( geoprivacy: Observation::OBSCURED )
    CheckList.refresh_with_observation( o, :latitude_was => p.latitude, :longitude_was => p.longitude )
    p.reload
    expect( p.check_list.taxon_ids ).to include( o.taxon_id )
  end
  
  it "should not remove taxa for new observations" do
    t = Taxon.make!( :species )
    lt = @check_list.add_taxon( t )
    expect( lt ).to be_auto_removable_from_check_list
    o = Observation.make!( taxon: t, latitude: @place.latitude, longitude: @place.longitude )
    CheckList.refresh_with_observation( o, new: true )
    @check_list.reload
    expect( @check_list.taxon_ids ).to include( o.taxon_id )
  end
  
  it "should add new taxa even if ancestors have already been added to this place" do
    parent = Taxon.make!( rank: Taxon::GENUS )
    child = Taxon.make!( rank: Taxon::SPECIES, parent: parent )
    @place.check_list.add_taxon( parent )
    expect( @place.taxon_ids ).to include( parent.id )
    
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: child )
    CheckList.refresh_with_observation( o )
    @place.reload
    expect( @place.taxon_ids ).to include( child.id )
  end
  
  it "should add the species along with infraspecies" do
    species = Taxon.make!( rank: Taxon::SPECIES )
    subspecies = Taxon.make!( rank: Taxon::SUBSPECIES, parent: species )
    o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: subspecies )
    CheckList.refresh_with_observation( o )
    @place.reload
    expect( @place.taxon_ids ).to include( species.id )
  end

  describe "with atlases and complete sets" do
    let( :country ) { make_place_with_geom( name: "Westeros", admin_level: Place::COUNTRY_LEVEL, wkt: "MULTIPOLYGON(((0 0,0 5,5 5,5 0,0 0)))" ) }
    let( :state ) { make_place_with_geom( name: "The North", admin_level: Place::STATE_LEVEL, parent: country, wkt: "MULTIPOLYGON(((1 1,1 3,3 3,3 1,1 1)))" ) }
    let( :genus ) { Taxon.make!( rank: Taxon::GENUS ) }
    let( :species ) { Taxon.make!( rank: Taxon::SPECIES, parent: genus ) }

    it "should add listed taxa descendant of admin_level 0 place if taxon atlased but not parent admin_level 0 place" do
      @atlas_place = Place.make!(admin_level: 0)
      @atlas_place.save_geom(
        GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt(
          "MULTIPOLYGON( ((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679 )))"
        )
      )
      @descendant_place = Place.make!(parent: @atlas_place)
      @descendant_place.save_geom(
        GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt(
          "MULTIPOLYGON( ((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679 )))"
        )
      )
      @atlas = Atlas.make!(is_active: true, taxon: @taxon)
      @atlas_place_check_list = List.find(@atlas_place.check_list_id)
      @descendant_place_check_list = List.find(@descendant_place.check_list_id)
      o = make_research_grade_observation( latitude: @descendant_place.latitude, longitude: @descendant_place.longitude, taxon: @taxon )
      expect( @descendant_place_check_list.taxon_ids ).not_to include @taxon.id
      expect( @atlas_place_check_list.taxon_ids ).not_to include @taxon.id
      CheckList.refresh_with_observation( o )
      @descendant_place_check_list.reload
      @atlas_place_check_list.reload
      expect( @descendant_place_check_list.taxon_ids ).to include @taxon.id
      expect( @atlas_place_check_list.taxon_ids ).not_to include @taxon.id
    end
    
    it "should remove listed taxa if observation deleted" do
      o = make_research_grade_observation( latitude: @place.latitude, longitude: @place.longitude, taxon: @taxon )
      expect( @place.place_geometry.geom ).not_to be_blank
      expect( o.geom ).not_to be_blank
      @check_list.add_taxon( @taxon )
      without_delay { CheckList.refresh_with_observation( o ) }
      @check_list.reload
      expect( @check_list.taxon_ids ).to include @taxon.id
      observation_id = o.id
      o.destroy
      without_delay { CheckList.refresh_with_observation( observation_id, taxon_id: @taxon.id ) }
      @check_list.reload
      expect( @check_list.taxon_ids ).not_to include @taxon.id
    end

    it "should add a listed taxon if there is an inactive atlas of the observed taxon" do
      atlas = make_atlas_with_presence( is_active: false, place: country, taxon: species )
      expect( state.check_list.taxa ).not_to include species
      o = make_research_grade_observation( taxon: species, latitude: 2, longitude: 2 )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).to include species
    end
    it "should add a listed taxon if there is an inactive atlas of an ancestor of the observed taxon" do
      atlas = make_atlas_with_presence( is_active: false, place: country, taxon: genus )
      expect( state.check_list.taxa ).not_to include species
      o = make_research_grade_observation( taxon: species, latitude: 2, longitude: 2 )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).to include species
    end
    it "should not add listed taxa for places outside of an active atlas of the observed taxon" do
      atlas = make_atlas_with_presence( taxon: species )
      expect( state.check_list.taxa ).not_to include species
      o = make_research_grade_observation( taxon: species, latitude: 2, longitude: 2 )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).not_to include species
    end
    it "should add a listed taxon for a place that descends from a place in an active atlas of the observed taxon" do
      atlas = make_atlas_with_presence( place: country, taxon: species )
      expect( state.check_list.taxa ).not_to include species
      o = make_research_grade_observation( taxon: species, latitude: 2, longitude: 2 )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).to include species
    end
    it "should add a listed taxon if there is an inactive complete set for the observed taxon" do
      o = make_research_grade_observation( taxon: species, latitude: state.latitude, longitude: state.longitude )
      complete_set = CompleteSet.make!( is_active: false, taxon: species )
      expect( state.check_list.taxa ).not_to include( species )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).to include( species )
    end
    it "should add a listed taxon if there is an inactive complete set for an ancestor of the observed taxon" do
      o = make_research_grade_observation( taxon: species, latitude: state.latitude, longitude: state.longitude )
      complete_set = CompleteSet.make!( is_active: false, taxon: genus )
      expect( state.check_list.taxa ).not_to include( species )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).to include( species )
    end
    it "should not add listed taxa if there is an active complete set for an ancestor of the observed taxon that does not contain the observed taxon" do
      complete_set = CompleteSet.make!( is_active: true, taxon: genus, place: country )
      expect( complete_set.get_taxa_for_place_taxon ).not_to include species
      o = make_research_grade_observation( taxon: species, latitude: state.latitude, longitude: state.longitude )
      expect( state.check_list.taxa ).not_to include( species )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).not_to include( species )
    end
    it "should add a listed taxon for a place that descends from a place with an active complete set for an ancestor of the observed taxon that includes the observed taxon" do
      ListedTaxon.make!( list: country.check_list, taxon: species )
      complete_set = CompleteSet.make!( is_active: true, taxon: genus, place: country )
      expect( complete_set.get_taxa_for_place_taxon ).to include species
      o = make_research_grade_observation( taxon: species, latitude: state.latitude, longitude: state.longitude )
      expect( state.check_list.taxa ).not_to include( species )
      CheckList.refresh_with_observation( o )
      state.reload
      expect( state.check_list.taxa ).to include( species )
    end
  end

end

describe CheckList, "sync_with_parent" do
  it "should add taxa to the parent" do
    parent_place = Place.make!
    parent_list = parent_place.check_list
    place = Place.make!( parent: parent_place )
    list = place.check_list
    taxon = Taxon.make!
    
    list.add_taxon( taxon.id )
    expect( list.taxon_ids ).to include( taxon.id )
    list.sync_with_parent
    parent_list.reload
    expect( parent_list.taxon_ids ).to include( taxon.id )
  end

  it "should work if parent doesn't have a check list" do
    parent = Place.make!( :prefers_check_lists => false )
    place = Place.make!( parent: parent )
    list = place.check_list
    taxon = Taxon.make!
    list.add_taxon( taxon )
    expect{ list.sync_with_parent }.to_not raise_error
  end
end
