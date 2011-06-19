require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Observation, "creation" do
  before(:each) do
    @taxon = Taxon.make
    @observation = Observation.make(:taxon => @taxon, :observed_on_string => 'yesterday at 1pm')
  end
  
  it "should be in the past" do
    @observation.observed_on.should <= Date.today
  end
  
  it "should not be in the future" do
    lambda {
      Observation.make(:observed_on_string => '2 weeks from now')
    }.should raise_error(ActiveRecord::RecordInvalid)
  end
  
  it "should properly set date and time" do
    Time.use_zone(@observation.time_zone) do
      @observation.observed_on.should == (1.day.ago.to_date)
      @observation.time_observed_at.hour.should be(13)
    end
  end
  
  it "should parse time from strings like October 30, 2008 10:31PM" do
    @observation.observed_on_string = 'October 30, 2008 10:31PM'
    @observation.save
    @observation.time_observed_at.in_time_zone(@observation.time_zone).hour.should be(22)
  end
  
  it "should parse a time zone from a code" do
    @observation.observed_on_string = 'October 30, 2008 10:31PM EST'
    @observation.save
    @observation.time_zone.should == ActiveSupport::TimeZone['Eastern Time (US & Canada)'].name
  end
  
  it "should not save a time if one wasn't specified" do
    @observation.observed_on_string = "April 2 2008"
    @observation.save
    @observation.time_observed_at.should be(nil)
  end
  
  it "should not save a time for 'today' or synonyms" do
    @observation.observed_on_string = "today"
    @observation.save
    @observation.time_observed_at.should be(nil)
  end
  
  it "should have an identification if taxon is known" do
    @observation.save
    @observation.reload
    @observation.identifications.empty?.should_not be(true)
  end
  
  it "should not have an identification if taxon is not known" do
    @observation.taxon = nil
    @observation.save
    @observation.identifications.empty?.should be(true)
  end
  
  it "should have an identification that maches the taxon" do
    @observation.reload
    @observation.identifications.first.taxon.should == @observation.taxon
  end
  
  it "should queue a DJ job for the life list" do
    stamp = Time.now
    Observation.make(:taxon => Taxon.make)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /refresh_for_user/}.should_not be_blank
  end
  
  it "should properly parse relative datetimes like '2 days ago'" do
    Time.use_zone(@observation.user.time_zone) do
      @observation.observed_on_string = '2 days ago'
      @observation.save
      @observation.observed_on.should == 2.days.ago.to_date
    end
  end
  
  it "should not save relative dates/times like 'yesterday'" do
    @observation.observed_on_string.split.include?('yesterday').should be(false)
  end
  
  it "should not save relative dates/times like 'this morning'" do
    @observation.observed_on_string = 'this morning'
    @observation.save
    @observation.reload
    @observation.observed_on_string.match('this morning').should be(nil)
  end
  
  it "should preserve observed_on_string if it did NOT contain a relative " +
     "time descriptor" do
    @observation.observed_on_string = "April 22 2008"
    @observation.save
    @observation.reload
    @observation.observed_on_string.should == "April 22 2008"
  end
  
  it "should parse dates that contain commas" do
    @observation.observed_on_string = "April 22, 2008"
    @observation.save
    @observation.observed_on.should_not be(nil)
  end
  
  it "should NOT parse a date like '2004'" do
    @observation.observed_on_string = "2004"
    @observation.save
    @observation.should_not be_valid
  end
  
  it "should default to the user's time zone" do
    @observation.time_zone.should == @observation.user.time_zone
  end
  
  it "should NOT use the user's time zone if another was set" do
    @observation.time_zone = 'Eastern Time (US & Canada)'
    @observation.save
    @observation.should be_valid
    @observation.reload
    @observation.time_zone.should_not == @observation.user.time_zone
    @observation.time_zone.should == 'Eastern Time (US & Canada)'
  end
  
  it "should save the time in the time zone selected" do
    @observation.time_zone = 'Eastern Time (US & Canada)'
    @observation.save
    @observation.should be_valid
    @observation.time_observed_at.in_time_zone(@observation.time_zone).hour.should be(13)
  end
  
  it "should set the time zone to UTC if the user's time zone is blank" do
    u = User.make
    u.update_attribute(:time_zone, nil)
    u.time_zone.should be_blank
    o = Observation.new(:user => u)
    o.save
    o.time_zone.should == 'UTC'
  end
  
  it "should trim whitespace from species_guess" do
    @observation.species_guess = " Anna's Hummingbird     "
    @observation.save
    @observation.species_guess.should == "Anna's Hummingbird"
  end
  
  it "should increment the counter cache in users" do
    old_count = @observation.user.observations_count
    Observation.make(:user => @observation.user)
    @observation.reload
    @observation.user.observations_count.should == old_count + 1
  end
  
  describe "species_guess parsing" do
    it "should choose a taxon if the guess corresponds to a unique taxon" do
      taxon = Taxon.make
      @observation.taxon = nil
      @observation.species_guess = taxon.name
      @observation.save
      @observation.taxon_id.should == taxon.id
    end

    it "should choose a taxon from species_guess if exact matches form a subtree" do
      taxon = Taxon.make(:rank => "species", :name => "Spirolobicus bananaensis")
      child = Taxon.make(:rank => "subspecies", :parent => taxon, :name => "#{taxon.name} foo")
      common_name = "Spiraled Banana Shrew"
      TaxonName.make(:taxon => taxon, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      TaxonName.make(:taxon => child, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      @observation.taxon = nil
      @observation.species_guess = common_name
      @observation.save
      @observation.taxon_id.should == taxon.id
    end

    it "should not choose a taxon from species_guess if exact matches don't form a subtree" do
      taxon = Taxon.make(:rank => "species", :name => "Spirolobicus bananaensis")
      child = Taxon.make(:rank => "subspecies", :parent => taxon, :name => "#{taxon.name} foo")
      taxon2 = Taxon.make(:rank => "species")
      common_name = "Spiraled Banana Shrew"
      TaxonName.make(:taxon => taxon, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      TaxonName.make(:taxon => child, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      TaxonName.make(:taxon => taxon2, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      @observation.taxon = nil
      @observation.species_guess = common_name
      @observation.save
      @observation.taxon_id.should be_blank
    end

    it "should choose a taxon from species_guess if exact matches form a subtree regardless of case" do
      taxon = Taxon.make(:rank => "species", :name => "Spirolobicus bananaensis")
      child = Taxon.make(:rank => "subspecies", :parent => taxon, :name => "#{taxon.name} foo")
      common_name = "Spiraled Banana Shrew"
      TaxonName.make(:taxon => taxon, :name => common_name.downcase, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      TaxonName.make(:taxon => child, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      @observation.taxon = nil
      @observation.species_guess = common_name
      @observation.save
      @observation.taxon_id.should == taxon.id
    end
  end
  
  it "should allow lots of sigfigs" do
    lat =  37.91143999
    lon = -122.2687819
    @observation.latitude = lat
    @observation.longitude = lon
    @observation.save
    @observation.reload
    @observation.latitude.should == lat
    @observation.longitude.should == lon
  end
  
  it "should set lat/lon if entered in place_guess" do
    lat =  37.91143999
    lon = -122.2687819
    @observation.latitude.should be_blank
    @observation.place_guess = "#{lat}, #{lon}"
    @observation.save
    @observation.latitude.to_f.should == lat
    @observation.longitude.to_f.should == lon
  end
  
  it "should set lat/lon if entered in place_guess as NSEW" do
    lat =  -37.91143999
    lon = -122.2687819
    @observation.latitude.should be_blank
    @observation.place_guess = "S#{lat * -1}, W#{lon * -1}"
    @observation.save
    @observation.latitude.to_f.should == lat
    @observation.longitude.to_f.should == lon
  end
  
  it "should not set lat/lon for addresses with numbers" do
    o = Observation.make(:place_guess => "Apt 1, 33 Figueroa Ave., Somewhere, CA")
    o.latitude.should be_blank
  end
  
  it "should not set lat/lon for addresses with zip codes" do
    o = Observation.make(:place_guess => "94618")
    o.latitude.should be_blank
    o = Observation.make(:place_guess => "94618-5555")
    o.latitude.should be_blank
  end
end

describe Observation, "updating" do
  before(:each) do
    @observation = Observation.make(
      :taxon => Taxon.make, 
      :observed_on_string => 'yesterday at 1pm', 
      :time_zone => 'UTC')
  end
  
  it "should destroy the owner's identifications if the taxon has been removed" do
    @observation.identifications.select do |ident|
      ident.user_id == @observation.user_id
    end.empty?.should_not be(true)
    @observation.taxon_id = nil
    @observation.save
    @observation.reload
    @observation.identifications.select do |ident|
      ident.user_id == observation.user_id
    end.empty?.should be(true)
  end
  
  it "should update the owner's identification if the taxon has changed" do
    owners_ident = @observation.identifications.select do |ident|
      ident.user_id == @observation.user_id
    end.first
    owners_ident.taxon.name.should == @observation.taxon.name
    
    psre = Taxon.make
    @observation.taxon.should_not be(psre)
    @observation.taxon = psre
    @observation.save
    @observation.reload
    owners_ident = @observation.identifications.select do |ident|
      ident.user_id == @observation.user_id
    end.first
    owners_ident.taxon.should == psre
  end

  # # Handled by DJ
  # it "should add the taxon to the user's life list if not there already" do
  #   psre = Taxon.find_by_name("Pseudacris regilla")
  #   @observation.taxon = psre
  #   @observation.user.life_list.taxa.map(&:id).should include(@observation.taxon_id_was)
  #   @observation.user.life_list.taxa.should_not include(@observation.taxon)
  #   
  #   @observation.save
  #   @observation.reload
  # 
  #   @observation.user.life_list.taxa.should include(@observation.taxon)
  # end
  
  it "should properly set date and time" do
    @observation.save
    @observation.observed_on_string = 'March 16 2007 at 2pm'
    @observation.save
    @observation.observed_on.should == Date.parse('2007-03-16')
    Time.use_zone(@observation.time_zone) do
      @observation.time_observed_at.hour.should be(14)
    end
  end
  
  it "should not save a time if one wasn't specified" do
    @observation.save
    @observation.time_observed_at.should_not be(nil)
    @observation.observed_on_string = "April 2 2008"
    @observation.save
    @observation.time_observed_at.should be(nil)
  end
  
  it "should set an iconic taxon if the taxon was set" do
    obs = Observation.make
    obs.iconic_taxon.should be_blank
    taxon = Taxon.make(:iconic_taxon => Taxon.make(:is_iconic => true))
    taxon.iconic_taxon.should_not be_blank
    obs.taxon = taxon
    obs.save!
    obs.iconic_taxon.name.should == taxon.iconic_taxon.name
  end
  
  it "should remove an iconic taxon if the taxon was removed" do
    taxon = Taxon.make(:iconic_taxon => Taxon.make(:is_iconic => true))
    taxon.iconic_taxon.should_not be_blank
    obs = Observation.make(:taxon => taxon)
    obs.iconic_taxon.should_not be_blank
    obs.taxon = nil
    obs.save!
    obs.reload
    obs.iconic_taxon.should be_blank
  end
  
  it "should nilify positional_accuracy if accuracy not set and position changed" do
    obs = Observation.make(:latitude => 1, :longitude => 1, :positional_accuracy => 10)
    obs.update_attributes(:latitude => 2)
    obs.reload
    obs.positional_accuracy.should be_blank
  end
  
  it "should refresh queue refresh jobs for associated project lists if the taxon changed" do
    o = Observation.make(:taxon => Taxon.make)
    po = ProjectObservation.make(:observation => o)
    Delayed::Job.delete_all
    o.update_attributes(:taxon => Taxon.make)
    stamp = Time.now
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    # puts jobs.detect{|j| j.handler =~ /\:refresh_project_list\n/}.handler.inspect
    jobs.select{|j| j.handler =~ /\:refresh_project_list\n/}.should_not be_blank
  end
  
  it "should not allow impossible coordinates" do
    o = Observation.make
    o.update_attributes(:latitude => 100)
    o.should_not be_valid
    
    o = Observation.make
    o.update_attributes(:longitude => 200)
    o.should_not be_valid
    
    o = Observation.make
    o.update_attributes(:latitude => -100)
    o.should_not be_valid
    
    o = Observation.make
    o.update_attributes(:longitude => -200)
    o.should_not be_valid
  end
end

describe Observation, "destruction" do
  fixtures :observations, :identifications, :users, :taxa, :lists, :listed_taxa
  before(:each) do
    @observation = Observation.create(
      :user => User.find_by_login('aaron'), # aaron shouldn't have ANY  obs
      :taxon => Taxon.find_by_name('Ensatina eschscholtzii'),
      :observed_on_string => 'yesterday at 1pm',
      :time_zone => 'UTC'
    )
  end
  
  it "should decrement the counter cache in users" do
    user = @observation.user
    user.reload
    old_count = user.observations_count
    @observation.destroy
    user.reload
    user.observations_count.should == old_count - 1
  end
end

describe Observation, "named scopes" do
  fixtures :observations, :users, :taxa
  
  # Valid UTC is something like:
  # '2008-01-01T01:00:00+00:00'
  # '2008-11-30T18:53:15+00:00'
  before(:each) do
    @after = 13.months.ago
    @before = 5.months.ago
    
    @after_formats = [@after, @after.iso8601]
    @before_formats = [@before, @before.iso8601]

    @pos = Observation.create(
      :user => User.find_by_login('aaron'),
      :taxon => Taxon.find_by_name('Ensatina eschscholtzii'),
      :observed_on_string => '14 months ago',
      :id_please => true,
      :latitude => 20.01,
      :longitude => 20.01,
      :created_at => 14.months.ago,
      :time_zone => 'UTC'
    )
    
    @neg = Observation.create(
      :user => User.find_by_login('aaron'),
      :taxon => Taxon.find_by_name('Ensatina eschscholtzii'),
      :observed_on_string => 'yesterday at 1pm',
      :latitude => 40,
      :longitude => 40,
      :time_zone => 'UTC'
    )
    
    @between = Observation.create(
      :user => User.find_by_login('aaron'),
      :taxon => Taxon.find_by_name('Ensatina eschscholtzii'),
      :observed_on_string => '6 months ago',
      :created_at => 6.months.ago,
      :time_zone => 'UTC'
    )
    
    @aaron_saw_an_amphibian = @pos
    @aaron_saw_a_mollusk = Observation.create(
      :user => User.find_by_login('aaron'),
      :taxon => Taxon.find_by_name('Mollusca'),
      :observed_on_string => '6 months ago',
      :created_at => 6.months.ago,
      :time_zone => 'UTC'
    )
    @aaron_saw_a_mystery = Observation.create(
      :user => User.find_by_login('aaron'),
      :observed_on_string => '6 months ago',
      :created_at => 6.months.ago,
      :time_zone => 'UTC'
    )
    
    Observation.record_timestamps = false
    @pos.updated_at = 14.months.ago
    @pos.save
    
    @between.updated_at = 6.months.ago
    @between.save
    Observation.record_timestamps = true
  end
  
  it "should find observations in a bounding box" do
    obs = Observation.in_bounding_box(20,20,30,30)
    obs.should include(@pos)
    obs.should_not include(@neg)
  end
  
  it "should find observations using the shorter box method" do
    obs = Observation.near_point(20, 20).all
    obs.should include(@pos)
    obs.should_not include(@neg)
  end
  
  it "should find observations with latitude and longitude" do
    obs = Observation.has_geo()
    obs.should include(@pos, @neg)
    obs.should_not include(@between)
  end
  
  it "should find observations requesting identification" do 
    obs = Observation.has_id_please
    obs.should include(@pos)
    obs.should_not include(@neg)
  end
  
  it "should find observations with photos" do
    @pos.photos << FlickrPhoto.new(:native_photo_id => 1)
    obs = Observation.has_photos
    obs.should include(@pos)
    obs.should_not include(@neg)
  end
  
  it "should find observations observed after a certain time" do
    @after_formats.each do |format|
      obs = Observation.observed_after(format)
      obs.should include(@neg, @between)
      obs.should_not include(@pos)
    end
  end
  
  it "should find observations observed before a specific time" do
    @before_formats.each do |format|
      obs = Observation.observed_before(format)
      obs.should include(@pos, @between)
      obs.should_not include(@neg)
    end
  end
  
  it "should find observations observed between two time bounds" do
    @after_formats.each do |after_format|
      @before_formats.each do |before_format|
        obs = Observation.observed_after(after_format).observed_before(before_format)
        obs.should include(@between)
        obs.should_not include(@pos, @neg)
      end
    end
  end
  
  it "should find observations created after a certain time" do
    @after_formats.each do |format|
      obs = Observation.created_after(format)
      obs.should include(@neg, @between)
      obs.should_not include(@pos)
    end
  end
  
  it "should find observations created before a specific time" do
    @before_formats.each do |format|
      obs = Observation.created_before(format)
      obs.should include(@pos, @between)
      obs.should_not include(@neg)
    end
  end

  it "should find observations created between two time bounds" do
    @after_formats.each do |after_format|
      @before_formats.each do |before_format|
        obs = Observation.created_after(after_format).created_before(before_format)
        obs.should include(@between)
        obs.should_not include(@pos, @neg)
      end
    end
  end
 
  it "should find observations updated after a certain time" do
    @after_formats.each do |format|
      obs = Observation.updated_after(format)
      obs.should include(@neg, @between)
      obs.should_not include(@pos)
    end
  end
  
  it "should find observations updated before a specific time" do
    @before_formats.each do |format|
      obs = Observation.updated_before(format)
      obs.should include(@pos, @between)
      obs.should_not include(@neg)
    end
  end
  
  it "should find observations updated between two time bounds" do
    @after_formats.each do |after_format|
      @before_formats.each do |before_format|
        obs = Observation.updated_after(after_format).updated_before(before_format)
        obs.should include(@between)
        obs.should_not include(@pos, @neg)
      end
    end
  end
  
  it "should find observations in one iconic taxon" do
    observations = Observation.has_iconic_taxa(taxa(:Mollusca))
    observations.should include(@aaron_saw_a_mollusk)
    observations.should_not include(@aaron_saw_an_amphibian)
  end
  
  it "should find observations in many iconic taxa" do
    observations = Observation.has_iconic_taxa(
      [taxa(:Mollusca), taxa(:Amphibia)])
    observations.should include(@aaron_saw_a_mollusk)
    observations.should include(@aaron_saw_an_amphibian)
  end
  
  it "should find observations with NO iconic taxon" do
    observations = Observation.has_iconic_taxa(
      [taxa(:Mollusca), nil])
    observations.should include(@aaron_saw_a_mollusk)
    observations.should include(@aaron_saw_a_mystery)
  end
  
  it "should order observations by created_at" do
    last_obs = Observation.all(:order => 'created_at desc').first
    Observation.order_by('created_at').last.should === last_obs
  end
  
  it "should reverse order observations by created_at" do
    last_obs = Observation.all(:order => 'created_at desc').first
    Observation.order_by('created_at DESC').first.should === last_obs
  end
  
  it "should not find anything for a non-existant taxon ID" do
    Observation.of(91919191).should be_empty
  end
end

describe Observation do
  describe "private coordinates" do
    before(:each) do
      @taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
    end
    
    it "should be set automatically if the taxon is threatened" do
      observation = Observation.make(:taxon => @taxon, :latitude => 38, :longitude => -122)
      observation.taxon.should be_threatened
      observation.private_longitude.should_not be_blank
      observation.private_longitude.should_not == observation.longitude
    end
    
    it "should be set automatically if the taxon's parent is threatened" do
      child = Taxon.make(:parent => @taxon, :rank => "subspecies")
      observation = Observation.make(:taxon => child, :latitude => 38, :longitude => -122)
      observation.taxon.should_not be_threatened
      observation.private_longitude.should_not be_blank
      observation.private_longitude.should_not == observation.longitude
    end
    
    it "should be unset if the taxon changes to something unthreatened" do
      observation = Observation.make(:taxon => @taxon, :latitude => 38, :longitude => -122)
      observation.taxon.should be_threatened
      observation.private_longitude.should_not be_blank
      observation.private_longitude.should_not == observation.longitude
      
      observation.update_attributes(:taxon => Taxon.make)
      observation.taxon.should_not be_threatened
      observation.private_longitude.should be_blank
    end
    
    it "should remove coordinates from place_guess" do
      [
        "38, -122",
        "38.284, -122.23452",
        "38.284N, -122.23452 W",
        "N38.284, W 122.23452",
        "44.43411 N 122.11360 W",
        "S35 46' 52.8\", E78 43' 6\"",
        "35° 46' 52.8\" N, 78° 43' 6\" W"
      ].each do |place_guess|
        observation = Observation.make(:place_guess => place_guess)
        observation.latitude.should_not be_blank
        observation.update_attributes(:taxon => @taxon)
        observation.place_guess.to_s.should == ""
      end
    end
    
    it "should not be included in json" do
      observation = Observation.make(:taxon => @taxon, :latitude => 38, :longitude => -122)
      observation.to_json.should_not match(/private_latitude/)
    end
    
    it "should not be included in a json array" do
      observation = Observation.make(:taxon => @taxon, :latitude => 38, :longitude => -122)
      Observation.make
      observations = Observation.paginate(:page => 1, :per_page => 2, :order => "id desc")
      observations.to_json.should_not match(/private_latitude/)
    end
  end
  
  describe "obscure_coordinates" do
    it "should not affect observations without coordinates" do
      o = Observation.make
      o.latitude.should be_blank
      o.obscure_coordinates
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
  end
  
  describe "unobscure_coordinates" do
    it "should work" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      true_lat = 38.0
      true_lon = -122.0
      o = Observation.make(:taxon => taxon, :latitude => true_lat, :longitude => true_lon)
      o.should be_coordinates_obscured
      o.latitude.to_f.should_not == true_lat
      o.longitude.to_f.should_not == true_lon
      o.unobscure_coordinates
      o.should_not be_coordinates_obscured
      o.latitude.to_f.should == true_lat
      o.longitude.to_f.should == true_lon
    end
    
    it "should not affect observations without coordinates" do
      o = Observation.make
      o.latitude.should be_blank
      o.unobscure_coordinates
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
    
    it "should not obscure observations with obscured geoprivacy" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make(:latitude => 38, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      o.unobscure_coordinates
      o.should be_coordinates_obscured
    end
    
    it "should not obscure observations with private geoprivacy" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make(:latitude => 38, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.unobscure_coordinates
      o.should be_coordinates_obscured
      o.latitude.should be_blank
    end
  end
  
  describe "obscure_coordinates_for_observations_of" do
    it "should work" do
      taxon = Taxon.make(:rank => "species")
      true_lat = 38.0
      true_lon = -122.0
      obs = []
      3.times do
        obs << Observation.make(:taxon => taxon, :latitude => true_lat, :longitude => true_lon)
        obs.last.should_not be_coordinates_obscured
      end
      Observation.obscure_coordinates_for_observations_of(taxon)
      obs.each do |o|
        o.reload
        o.should be_coordinates_obscured
      end
    end
    
    it "should remove coordinates from place_guess" do
      taxon = Taxon.make(:rank => "species")
      observation = Observation.make(:place_guess => "38, -122", :taxon => taxon)
      observation.latitude.should_not be_blank
      Observation.obscure_coordinates_for_observations_of(taxon)
      observation.reload
      observation.place_guess.to_s.should == ""
    end
    
    it "should not affect observations without coordinates" do
      taxon = Taxon.make(:rank => "species")
      o = Observation.make(:taxon => taxon)
      o.latitude.should be_blank
      Observation.obscure_coordinates_for_observations_of(taxon)
      o.reload
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
    
    it "should not add coordinates to private observations" do
      taxon = Taxon.make(:rank => "species")
      observation = Observation.make(:place_guess => "38, -122", :taxon => taxon, :geoprivacy => Observation::PRIVATE)
      observation.latitude.should be_blank
      observation.private_latitude.should_not be_blank
      Observation.obscure_coordinates_for_observations_of(taxon)
      observation.reload
      observation.latitude.should be_blank
      observation.private_latitude.should_not be_blank
    end
  end
  
  describe "unobscure_coordinates_for_observations_of" do
    it "should work" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      true_lat = 38.0
      true_lon = -122.0
      obs = []
      3.times do
        obs << Observation.make(:taxon => taxon, :latitude => true_lat, :longitude => true_lon)
        obs.last.should be_coordinates_obscured
      end
      Observation.unobscure_coordinates_for_observations_of(taxon)
      obs.each do |o|
        o.reload
        o.should_not be_coordinates_obscured
      end
    end
    
    it "should not affect observations without coordinates" do
      taxon = Taxon.make(:rank => "species")
      o = Observation.make(:taxon => taxon)
      o.latitude.should be_blank
      Observation.unobscure_coordinates_for_observations_of(taxon)
      o.reload
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
    
    it "should not obscure observations with obscured geoprivacy" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make(:latitude => 38, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      Observation.unobscure_coordinates_for_observations_of(taxon)
      o.reload
      o.should be_coordinates_obscured
    end
    
    it "should not obscure observations with private geoprivacy" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make(:latitude => 38, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      Observation.unobscure_coordinates_for_observations_of(taxon)
      o.reload
      o.should be_coordinates_obscured
      o.latitude.should be_blank
    end
  end
  
  describe "geoprivacy" do
    it "should obscure coordinates when private" do
      o = Observation.make(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.should be_coordinates_obscured
    end
    
    it "should remove public coordinates when private" do
      o = Observation.make(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.latitude.should be_blank
      o.longitude.should be_blank
    end
    
    it "should remove public coordinates when private if coords change but not geoprivacy" do
      o = Observation.make(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.update_attributes(:latitude => 1, :longitude => 1)
      o.should be_coordinates_obscured
      o.latitude.should be_blank
      o.longitude.should be_blank
    end
    
    it "should obscure coordinates when obscured" do
      o = Observation.make(:latitude => 37, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      o.should be_coordinates_obscured
    end
    
    it "should not unobscure observations of threatened taxa" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make(:taxon => taxon, :latitude => 37, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      o.should be_coordinates_obscured
      o.update_attributes(:geoprivacy => nil)
      o.geoprivacy.should be_blank
      o.should be_coordinates_obscured
    end
    
    it "should remove public coordinates when private even if taxon threatened" do
      taxon = Taxon.make(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make(:latitude => 37, :longitude => -122, :taxon => taxon)
      o.should be_coordinates_obscured
      o.latitude.should_not be_blank
      o.update_attributes(:geoprivacy => Observation::PRIVATE)
      o.latitude.should be_blank
      o.longitude.should be_blank
    end
    
    it "should restore public coordinates when removing geoprivacy" do
      lat, lon = [37, -122]
      o = Observation.make(:latitude => lat, :longitude => lon, :geoprivacy => Observation::PRIVATE)
      o.latitude.should be_blank
      o.longitude.should be_blank
      o.update_attributes(:geoprivacy => nil)
      o.latitude.to_f.should == lat
      o.longitude.to_f.should == lon
    end
  end
end

