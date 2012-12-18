require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Place do
  it "should have taxa" do
    place = Place.make!
    taxon = Taxon.make!
    place.check_list.add_taxon(taxon)
    taxon.places.should_not be_empty
  end
end

describe Place, "creation" do
  before(:each) do
    @place = Place.make!
  end
  
  it "should create a default check_list" do
    @place.check_list.should_not be_nil
  end

  it "should not create a default check list if not preferred" do
    p = Place.make!(:prefers_check_lists => false)
    p.check_list.should be_blank
  end
  
  it "should have no default type" do
    @place.place_type_name.should be_blank
  end
end

describe Place, "updating" do
  before(:each) do
    @place = Place.make!
  end
  
  it "should not have itself as a parent" do
    @place.parent = @place
    @place.should_not be_valid
    @place.errors[:parent_id].should_not be_blank
  end
end

describe Place, "import by WOEID" do
  before(:each) do
    @woeid = '28337864';
    @place = Place.import_by_woeid(@woeid)
  end
  
  it "should create ancestors" do
    @place.should have_at_least(2).ancestors
  end
end

# These pass individually but fail as a group, probably due to some 
# transaction weirdness.
describe Place, "merging" do
  before(:each) do
    @place = Place.make!(:name => "Berkeley")
    @place.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.247619628906 37.8547693305679,-122.284870147705 37.8490764953623,-122.299289703369 37.8909492165781,-122.250881195068 37.8970452004104,-122.239551544189 37.8719807055375,-122.247619628906 37.8547693305679)))"))
    3.times do
      @place.check_list.taxa << Taxon.make!
    end
    @old_place_listed_taxa = @place.listed_taxa.all
    @place_geom = @place.place_geometry.geom
    @mergee = Place.make!(:name => "Oakland")
    @mergee.save_geom(MultiPolygon.from_ewkt("MULTIPOLYGON(((-122.332077026367 37.8081564815264,-122.251739501953 37.7864534344207,-122.215347290039 37.757687076897,-122.264785766602 37.7424852382661,-122.21809387207 37.6990342079442,-122.14531 37.71152,-122.126083374023 37.7826547456574,-122.225646972656 37.8618440983709,-122.259635925293 37.8561518095069,-122.332077026367 37.8081564815264)))"))
    2.times do
      @mergee.check_list.taxa << Taxon.make!
    end
    @mergee.check_list.taxa << @place.check_list.taxa.first
    @mergee_listed_taxa = @mergee.listed_taxa.all.to_a
    @mergee_geom = @mergee.place_geometry.geom
    @merged_place = @place.merge(@mergee)
  end
  
  it "should return a valid place if the merge was successful" do
    @merged_place.should be_valid
  end
  
  it "should destroy the mergee" do
    lambda {
      @mergee.reload
    }.should raise_error ActiveRecord::RecordNotFound
  end
  
  it "should default to preserving all the primary's attributes" do
    @merged_place.reload
    Place.column_names.each do |column_name|
      @place.send(column_name).should == @merged_place.send(column_name)
    end
  end
  
  it "should accept an array of attributes to take from the mergee" do
    narnia_name = 'Narnia'
    narnia = Place.create(:name => narnia_name, :latitude => 10, :longitude => 10)
    mearth = Place.create(:name => 'Middle Earth', :latitude => 20, :longitude => 20)
    merged_place = narnia.merge(mearth, :keep => [:latitude, :longitude])
    merged_place.latitude.should == mearth.latitude
    merged_place.longitude.should == mearth.longitude
    merged_place.name.should == narnia_name
  end
  
  it "should not have errors if keeping the name of the deleted place" do
    narnia = Place.create(:name => 'Narnia', :latitude => 20, :longitude => 20)
    mearth = Place.create(:name => 'Middle Earth', :latitude => 20, :longitude => 20)
    merged_place = narnia.merge(mearth, :keep => [:name])
    puts "Errors on merged_place: #{merged_place.errors.full_messages.join(', ')}" unless merged_place.valid?
    merged_place.should be_valid
  end
  
  it "should move all the mergee's listed_taxa to the primary" do
    @mergee_listed_taxa.each do |listed_taxon|
      next if @old_place_listed_taxa.map(&:taxon_id).include?(listed_taxon.taxon_id)
      lambda {
        listed_taxon.reload
      }.should_not raise_error ActiveRecord::RecordNotFound 
      listed_taxon.place_id.should == @place.id
      listed_taxon.list_id.should == @place.check_list_id
    end
  end
  
  it "should result in valid listed taxa (i.e. no duplicates)" do
    @place.listed_taxa.each do |listed_taxon|
      listed_taxon.should be_valid
    end
  end
  
  it "should merge the place geometries" do
    @place.place_geometry.geom.geometries.size.should > @place_geom.geometries.size
  end
  
  it "should merge the place geometries when the keeper has no geom" do
    p = Place.make!
    p.place_geometry.should be_blank
    p.merge(@merged_place)
    p.place_geometry.should_not be_blank
  end
end

describe Place, "bbox_contains_lat_lng?" do
  it "should work" do
    place = Place.make!(:latitude => 0, :longitude => 0, :swlat => -1, :swlng => -1, :nelat => 1, :nelng => 1)
    place.bbox_contains_lat_lng?(0, 0).should be_true
    place.bbox_contains_lat_lng?(0.5, 0.5).should be_true
    place.bbox_contains_lat_lng?(2, 2).should be_false
    place.bbox_contains_lat_lng?(2, nil).should be_false
    place.bbox_contains_lat_lng?(nil, nil).should be_false
    place.bbox_contains_lat_lng?('', '').should be_false
  end
  
  it "should work across the date line" do
    place = Place.make!(:latitude => 0, :longitude => 180, :swlat => -1, :swlng => 179, :nelat => 1, :nelng => -179)
    place.bbox_contains_lat_lng?(0, 180).should be_true
    place.bbox_contains_lat_lng?(0.5, -179.5).should be_true
    place.bbox_contains_lat_lng?(0, 0).should be_false
  end
end

