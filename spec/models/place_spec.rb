require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Place do
  it "should have taxa" do
    place = Place.make!
    taxon = Taxon.make!
    place.check_list.add_taxon(taxon)
    expect(taxon.places).to_not be_empty
  end
end

describe Place, "creation" do
  before(:each) do
    enable_elastic_indexing( Observation, Place )
    @place = Place.make!
  end
  after(:each) { disable_elastic_indexing( Observation, Place ) }
  
  it "should create a default check_list" do
    expect(@place.check_list).to_not be_nil
  end

  it "should not create a default check list if not preferred" do
    p = Place.make!(:prefers_check_lists => false)
    expect(p.check_list).to be_blank
  end
  
  it "should have no default type" do
    expect(@place.place_type_name).to be_blank
  end

  it "should add observed taxa to the checklist if geom set" do
    t = Taxon.make!
    o = make_research_grade_observation(:taxon => t, :latitude => 0.5, :longitude => 0.5)
    p = make_place_with_geom(:wkt => "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))")
    Delayed::Worker.new.work_off
    p.reload
    expect(p.check_list.taxa).to include t
  end

  it "should not allow titles that start with numbers" do
    p = Place.make(:name => "14")
    expect(p).to_not be_valid
    expect(p.errors[:name]).to_not be_blank
  end
end

describe Place, "updating" do
  before(:each) do
    @place = Place.make!
  end
  
  it "should not have itself as a parent" do
    @place.parent = @place
    expect(@place).to_not be_valid
    expect(@place.errors[:parent_id]).to_not be_blank
  end
end

describe Place, "import by WOEID" do
  before(:each) do
    @woeid = '28337864';
    @place = Place.import_by_woeid(@woeid)
  end
  
  it "should create ancestors" do
    expect(@place.ancestors.count).to be >= 2
  end
end

# These pass individually but fail as a group, probably due to some 
# transaction weirdness.
describe Place, "merging" do
  before(:each) do
    enable_elastic_indexing( Observation, Place )
    @place = Place.make!(:name => "Berkeley")
    @place.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
    3.times do
      @place.check_list.taxa << Taxon.make!
    end
    @old_place_listed_taxa = @place.listed_taxa.all
    @place_geom = @place.place_geometry.geom
    @reject = Place.make!(:name => "Oakland")
    @reject.save_geom(GeoRuby::SimpleFeatures::MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.332077026367 37.8081564815264,-122.251739501953 37.7864534344207,-122.215347290039 37.757687076897,-122.264785766602 37.7424852382661,-122.21809387207 37.6990342079442,-122.14531 37.71152,-122.126083374023 37.7826547456574,-122.225646972656 37.8618440983709,-122.259635925293 37.8561518095069,-122.332077026367 37.8081564815264)))"))
    2.times do
      @reject.check_list.taxa << Taxon.make!
    end
    @reject.check_list.taxa << @place.check_list.taxa.first
    @reject_listed_taxa = @reject.listed_taxa.all.to_a
    @reject_geom = @reject.place_geometry.geom
    @merged_place = @place.merge(@reject)
  end
  after(:each) { disable_elastic_indexing( Observation, Place ) }

  it "should return a valid place if the merge was successful" do
    expect(@merged_place).to be_valid
  end
  
  it "should destroy the reject" do
    expect {
      @reject.reload
    }.to raise_error ActiveRecord::RecordNotFound
  end
  
  it "should default to preserving all the primary's attributes" do
    @merged_place.reload
    Place.column_names.each do |column_name|
      expect(@place.send(column_name)).to eq @merged_place.send(column_name)
    end
  end
  
  it "should accept an array of attributes to take from the reject" do
    narnia_name = 'Narnia'
    narnia = Place.create(:name => narnia_name, :latitude => 10, :longitude => 10)
    mearth = Place.create(:name => 'Middle Earth', :latitude => 20, :longitude => 20)
    merged_place = narnia.merge(mearth, :keep => [:latitude, :longitude])
    expect(merged_place.latitude).to eq mearth.latitude
    expect(merged_place.longitude).to eq mearth.longitude
    expect(merged_place.name).to eq narnia_name
  end
  
  it "should not have errors if keeping the name of the deleted place" do
    narnia = Place.create(:name => 'Narnia', :latitude => 20, :longitude => 20)
    mearth = Place.create(:name => 'Middle Earth', :latitude => 20, :longitude => 20)
    merged_place = narnia.merge(mearth, :keep => [:name])
    puts "Errors on merged_place: #{merged_place.errors.full_messages.join(', ')}" unless merged_place.valid?
    expect(merged_place).to be_valid
  end
  
  it "should move all the reject's listed_taxa to the primary" do
    @reject_listed_taxa.each do |listed_taxon|
      next if @old_place_listed_taxa.map(&:taxon_id).include?(listed_taxon.taxon_id)
      expect {
        listed_taxon.reload
      }.to_not raise_error ActiveRecord::RecordNotFound 
      expect(listed_taxon.place_id).to eq @place.id
      expect(listed_taxon.list_id).to eq @place.check_list_id
    end
  end
  
  it "should result in valid listed taxa (i.e. no duplicates)" do
    @place.listed_taxa.each do |listed_taxon|
      expect(listed_taxon).to be_valid
    end
  end
  
  it "should merge the place geometries when the keeper has no geom" do
    p = Place.make!
    expect(p.place_geometry).to be_blank
    expect(@merged_place.place_geometry).not_to be_blank
    p.merge(@merged_place)
    p.reload
    expect(p.place_geometry).not_to be_blank
  end

  it "should move the rejects children over to the keeper" do
    keeper = Place.make!
    reject = Place.make!
    child = Place.make!(:parent => reject)
    keeper.merge(reject)
    child.reload
    expect(child.parent).to eq keeper
  end

  it "should update observations_places" do
    keeper = make_place_with_geom(wkt: "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))")
    reject = make_place_with_geom(wkt: "MULTIPOLYGON(((0 0,0 -1,-1 -1,-1 0,0 0)))")
    o = Observation.make!(latitude: reject.latitude, longitude: reject.longitude)
    op = o.observations_places.where(place_id: reject.id).first
    expect( op.place_id ).to eq reject.id
    keeper.merge(reject)
    op.reload
    expect( op.place_id ).to eq keeper.id
  end

  it "should not create duplicate observations_places" do
    wkt = "MULTIPOLYGON(((0 0,0 -1,-1 -1,-1 0,0 0)))"
    keeper = make_place_with_geom(wkt: wkt)
    reject = make_place_with_geom(wkt: wkt)
    o = Observation.make!(latitude: reject.latitude, longitude: reject.longitude)
    expect( o.observations_places.count ).to eq 2
    op = o.observations_places.where(place_id: reject.id).first
    expect( op.place_id ).to eq reject.id
    expect {
      keeper.merge(reject)
    }.not_to raise_error
    expect( keeper.observations_places.where(observation_id: o) ).not_to be_blank
  end
end

describe Place, "bbox_contains_lat_lng?" do
  it "should work" do
    place = Place.make!(:latitude => 0, :longitude => 0, :swlat => -1, :swlng => -1, :nelat => 1, :nelng => 1)
    expect(place.bbox_contains_lat_lng?(0, 0)).to be true
    expect(place.bbox_contains_lat_lng?(0.5, 0.5)).to be true
    expect(place.bbox_contains_lat_lng?(2, 2)).to be false
    expect(place.bbox_contains_lat_lng?(2, nil)).to be false
    expect(place.bbox_contains_lat_lng?(nil, nil)).to be false
    expect(place.bbox_contains_lat_lng?('', '')).to be false
  end
  
  it "should work across the date line" do
    place = Place.make!(:latitude => 0, :longitude => 180, :swlat => -1, :swlng => 179, :nelat => 1, :nelng => -179)
    expect(place.bbox_contains_lat_lng?(0, 180)).to be true
    expect(place.bbox_contains_lat_lng?(0.5, -179.5)).to be true
    expect(place.bbox_contains_lat_lng?(0, 0)).to be false
  end
end

describe Place do
  it "should be editable by curators" do
    p = Place.make!
    u = make_curator
    expect(p).to be_editable_by(u)
  end
  it "should be editable by the creator" do
    u = User.make!
    p = Place.make!(:user => u)
    expect(p).to be_editable_by(u)
  end

  it "should not be editable by non-curators who aren't the creator" do
    u = User.make!
    p = Place.make!(:user => User.make!)
    expect(p).to_not be_editable_by(u)
  end
end

describe Place, "display_name" do
  it "should be in correct order" do
    country = Place.make!(:code => "cn", :place_type => Place::PLACE_TYPE_CODES['country'])
    state = Place.make!(:code => "st", :place_type => Place::PLACE_TYPE_CODES['state'], :parent => country)
    place = Place.make!(:parent => state)
    expect(place.parent).to eq(state)
    expect(place.display_name(:reload => true)).to be =~ /, #{state.code}, #{country.code}$/
  end
end
