require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Observation, "creation" do
  fixtures :taxa, :taxon_names, :users, :lists, :listed_taxa, :observations
  before(:each) do
    @observation = Observation.new(
      :user => users(:quentin),
      :taxon => taxa(:Calypte_anna),
      :observed_on_string => 'yesterday at 1pm'
    )
  end
  
  it "should be in the past" do
    @observation.save
    @observation.observed_on.should <= Date.today
  end
  
  it "should not be in the future" do
    future_observation = Observation.new(
      :observed_on_string => '2 weeks from now'
    )
    future_observation.valid?
    future_observation.errors.on(:observed_on).should_not be(nil)
  end
  
  it "should properly set date and time" do
    @observation.save
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
    @observation.save
    @observation.reload
    @observation.identifications.first.taxon.should == @observation.taxon
  end
  
  it "should add a newly observed taxon to the user's life list" do
    @observation.taxon = Taxon.find_by_name("Ensatina eschscholtzii")
    @observation.user.life_list.taxa.should_not include(@observation.taxon)
    @observation.save
    @observation.reload
    @observation.user.life_list.taxa.should include(@observation.taxon)
  end
  
  it "should only update the life list for an already observed taxon" do
    user = @observation.user
    taxon = @observation.taxon
    @observation.save
    user.life_list.taxa.select {|t| t == taxon}.size.should == 1
    
    more_of_the_same = @observation.clone
    more_of_the_same.save
    user.life_list.taxa.select {|t| t == taxon}.size.should == 1
  end
  
  it "should properly parse relative datetimes like '2 days ago'" do
    Time.use_zone(@observation.user.time_zone) do
      @observation.observed_on_string = '2 days ago'
      @observation.save
      @observation.observed_on.should == 2.days.ago.to_date
    end
  end
  
  it "should not save relative dates/times like 'yesterday'" do
    @observation.save
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
    @observation.save
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
  
  it "should trim whitespace from species_guess" do
    @observation.species_guess = " Anna's Hummingbird     "
    @observation.save
    @observation.species_guess.should == "Anna's Hummingbird"
  end
  
  it "should increment the counter cache in users" do
    old_count = @observation.user.observations_count
    @observation.save
    @observation.reload
    @observation.user.observations_count.should == old_count + 1
  end
  
  it "should automatically set a taxon if the guess corresponds to a unique taxon" do
    @observation.taxon = nil
    @observation.species_guess = "Anna's Hummingbird"
    @observation.save
    @observation.taxon_id.should == taxa(:Calypte_anna).id
  end
end

describe Observation, "updating" do
  fixtures :observations, :identifications, :users, :taxa, :lists, 
           :listed_taxa, :goal_participants, :goal_contributions, :goal_rules, 
           :goals
  before(:each) do
    @observation = Observation.create(
      :user => users(:jill),
      :taxon => Taxon.find_by_name('Calypte anna'),
      :observed_on_string => 'yesterday at 1pm',
      :time_zone => 'UTC'
    )
  end
  
  it "should destroy the owner's identifications if the taxon has been " + 
     "removed" do
    observation = Observation.first
    observation.identifications.select do |ident|
      ident.user_id == observation.user_id
    end.empty?.should_not be(true)
    observation.taxon_id = nil
    observation.save
    observation.reload
    observation.identifications.select do |ident|
      ident.user_id == observation.user_id
    end.empty?.should be(true)
  end
  
  it "should update the owner's identification if the taxon has changed" do
    @observation.save
    @observation.reload
    
    owners_ident = @observation.identifications.select do |ident|
      ident.user_id == @observation.user_id
    end.first
    owners_ident.taxon.name.should == @observation.taxon.name
    
    psre = Taxon.find_by_name('Pseudacris regilla')
    @observation.taxon.should_not be(psre)
    @observation.taxon = psre
    @observation.save
    @observation.reload
    owners_ident = @observation.identifications.select do |ident|
      ident.user_id == @observation.user_id
    end.first
    owners_ident.taxon.should == psre
  end
  
  it "should add the taxon to the user's life list if not there already" do
    psre = Taxon.find_by_name("Pseudacris regilla")
    @observation.taxon = psre
    @observation.user.life_list.taxa.map(&:id).should include(@observation.taxon_id_was)
    @observation.user.life_list.taxa.should_not include(@observation.taxon)
    
    @observation.save
    @observation.reload

    @observation.user.life_list.taxa.should include(@observation.taxon)
  end
  
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
    @observation.taxon.should_not be(nil)
    @observation.save
    @observation.iconic_taxon.name.should == 'Aves'
  end
  
  it "should remove an iconic taxon if the taxon was removed" do
    @observation.save
    @observation.iconic_taxon.should_not be(nil)
    @observation.taxon = nil
    @observation.valid?
    @observation.errors.empty?.should be(true)
    @observation.save
    @observation.reload
    @observation.iconic_taxon.should be(nil)
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
    old_count = @observation.user.observations_count
    user = @observation.user
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
      :latitude => 25,
      :longitude => 25,
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
    obs = Observation.near_point(20, 20)
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
    @pos.flickr_photos << FlickrPhoto.new(:flickr_native_photo_id => 1)
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
