# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Observation, "creation" do
  before(:each) do
    @taxon = Taxon.make!
    @observation = Observation.make!(:taxon => @taxon, :observed_on_string => 'yesterday at 1pm')
  end
  
  it "should be in the past" do
    @observation.observed_on.should <= Date.today
  end
  
  it "should not be in the future" do
    lambda {
      Observation.make!(:observed_on_string => '2 weeks from now')
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
  
  it "should parse time from strings like 2011-12-23T11:52:06-0500" do
    @observation.observed_on_string = '2011-12-23T11:52:06-0500'
    @observation.save
    @observation.time_observed_at.in_time_zone(@observation.time_zone).hour.should be(11)
  end
  
  it "should parse time from strings like 2011-12-23T11:52:06.123" do
    @observation.observed_on_string = '2011-12-23T11:52:06.123'
    @observation.save
    @observation.time_observed_at.in_time_zone(@observation.time_zone).hour.should be(11)
  end
  
  it "should parse time and zone from July 9, 2012 7:52:39 AM ACST" do
    @observation.observed_on_string = 'July 9, 2012 7:52:39 AM ACST'
    @observation.save
    @observation.time_observed_at.in_time_zone(@observation.time_zone).hour.should be(7)
    @observation.time_zone.should == ActiveSupport::TimeZone['Adelaide'].name
  end

  it "should parse a bunch of test date strings" do
    [
      ['Fri Apr 06 2012 16:23:35 GMT-0500 (GMT-05:00)', {:month => 4, :day => 6, :hour => 16, :offset => "-05:00"}],
      ['Sun Nov 03 2013 08:15:25 GMT-0500 (GMT-5)', {:month => 11, :day => 3, :hour => 8, :offset => "-05:00"}],
      ['September 27, 2012 8:09:50 AM GMT+01:00', :month => 9, :day => 27, :hour => 8, :offset => "+01:00"],
      ['Thu Dec 26 2013 11:18:22 GMT+0530 (GMT+05:30)', :month => 12, :day => 26, :hour => 11, :offset => "+05:30"],
      ['2010-08-23 13:42:55 +0000', :month => 8, :day => 23, :hour => 13, :offset => "+00:00"]
    ].each do |date_string, opts|
      o = Observation.make!(:observed_on_string => date_string)
      o.observed_on.day.should be(opts[:day])
      o.observed_on.month.should be(opts[:month])
      o.time_observed_at.in_time_zone(o.time_zone).hour.should be(opts[:hour])
      zone = ActiveSupport::TimeZone[o.time_zone]
      zone.formatted_offset.should eq opts[:offset]
    end
  end

  it "should parse Spanish date strings" do
    [
      ['lun nov 04 2013 04:22:34 p.m. GMT-0600 (GMT-6)', {:month => 11, :day => 4, :hour => 16, :offset => "-06:00"}],
      ['lun dic 09 2013 23:37:08 GMT-0800 (GMT-8)', {:month => 12, :day => 9, :hour => 23, :offset => "-08:00"}],
      ['jue dic 12 2013 00:54:02 GMT-0800 (GMT-8)', {:month => 12, :day => 12, :hour => 0, :offset => "-08:00"}]
    ].each do |date_string, opts|
      o = Observation.make!(:observed_on_string => date_string)
      zone = ActiveSupport::TimeZone[o.time_zone]
      zone.formatted_offset.should eq opts[:offset]
      o.observed_on.month.should eq opts[:month]
      o.observed_on.day.should eq opts[:day]
      o.time_observed_at.in_time_zone(o.time_zone).hour.should eq opts[:hour]
    end
  end
  
  it "should parse a time zone from a code" do
    @observation.observed_on_string = 'October 30, 2008 10:31PM EST'
    @observation.save
    @observation.time_zone.should == ActiveSupport::TimeZone['Eastern Time (US & Canada)'].name
  end
  
  it "should parse time zone from strings like 2011-12-23T11:52:06-0500" do
    @observation.observed_on_string = '2011-12-23T11:52:06-0500'
    @observation.save
    zone = ActiveSupport::TimeZone[@observation.time_zone]
    zone.should_not be_blank
    zone.formatted_offset.should == "-05:00"
  end
  
  it "should not save a time if one wasn't specified" do
    @observation.observed_on_string = "April 2 2008"
    @observation.save
    @observation.time_observed_at.should be_blank
  end
  
  it "should not save a time for 'today' or synonyms" do
    @observation.observed_on_string = "today"
    @observation.save
    @observation.time_observed_at.should be(nil)
  end

  it "should not choke of bad dates" do
    @observation.observed_on_string = "this is not a date"
    lambda {
      @observation.save
    }.should_not raise_error
  end
  
  it "should have an identification if taxon is known" do
    @observation.save
    @observation.reload
    @observation.identifications.empty?.should_not be(true)
  end
  
  it "should not have an identification if taxon is not known" do
    o = Observation.make!
    o.identifications.to_a.should be_blank
  end
  
  it "should have an identification that matches the taxon" do
    @observation.reload
    @observation.identifications.first.taxon.should == @observation.taxon
  end
  
  it "should queue a DJ job to refresh lists" do
    Delayed::Job.delete_all
    stamp = Time.now
    Observation.make!(:taxon => Taxon.make!)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /List.*refresh_with_observation/m}.should_not be_blank
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
    u = User.make!
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
    Observation.make!(:user => @observation.user)
    @observation.reload
    @observation.user.observations_count.should == old_count + 1
  end
  
  it "should allow lots of sigfigs" do
    lat =  37.91143999
    lon = -122.2687819
    @observation.latitude = lat
    @observation.longitude = lon
    @observation.save
    @observation.reload
    @observation.latitude.to_f.should == lat
    @observation.longitude.to_f.should == lon
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
    o = Observation.make!(:place_guess => "Apt 1, 33 Figueroa Ave., Somewhere, CA")
    o.latitude.should be_blank
  end
  
  it "should not set lat/lon for addresses with zip codes" do
    o = Observation.make!(:place_guess => "94618")
    o.latitude.should be_blank
    o = Observation.make!(:place_guess => "94618-5555")
    o.latitude.should be_blank
  end
  
  describe "quality_grade" do
    it "should default to casual" do
      o = Observation.make!
      o.quality_grade.should == Observation::CASUAL_GRADE
    end
  end

  it "should trim to the user_agent to 255 char" do
    user_agent = <<-EOT
      Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR
      1.0.3705; .NET CLR 1.1.4322; Media Center PC 4.0; .NET CLR 2.0.50727;
      .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; .NET CLR 3.0.4506.2152;
      .NET CLR 3.5.30729; PeoplePal 7.0; PeoplePal 7.3; .NET4.0C; .NET4.0E;
      OfficeLiveConnector.1.5; OfficeLivePatch.1.3) w:PACBHO60
    EOT
    o = Observation.make!(:user_agent => user_agent)
    o.user_agent.size.should be < 256
  end

  it "should set the URI" do
    o = Observation.make!
    o.reload
    o.uri.should eq(FakeView.observation_url(o))
  end

  it "should not set the URI if already set" do
    uri = "http://www.somewhereelse.com/users/4"
    o = Observation.make!(:uri => uri)
    o.reload
    o.uri.should eq(uri)
  end

  it "should increment the taxon's counter cache" do
    t = Taxon.make!
    t.observations_count.should eq(0)
    o = without_delay {Observation.make!(:taxon => t)}
    t.reload
    t.observations_count.should eq(1)
  end

  it "should increment the taxon's ancestors' counter caches" do
    p = Taxon.make!
    t = Taxon.make!(:parent => p)
    p.observations_count.should eq(0)
    o = without_delay {Observation.make!(:taxon => t)}
    p.reload
    p.observations_count.should eq(1)
  end
end

describe Observation, "updating" do
  before(:each) do
    @observation = Observation.make!(
      :taxon => Taxon.make!, 
      :observed_on_string => 'yesterday at 1pm', 
      :time_zone => 'UTC')
  end

  it "should not destroy the owner's old identification if the taxon has changed" do
    t1 = Taxon.make!
    t2 = Taxon.make!
    o = Observation.make!(:taxon => t1)
    old_owners_ident = o.identifications.detect{|ident| ident.user_id == o.user_id}
    o.update_attributes(:taxon => t2)
    o.reload
    Identification.find_by_id(old_owners_ident.id).should_not be_blank
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
    @observation.time_observed_at_in_zone.hour.should eq(14)
  end
  
  it "should not save a time if one wasn't specified" do
    @observation.update_attributes(:observed_on_string => "April 2 2008")
    @observation.save
    @observation.time_observed_at.should be_blank
  end
  
  it "should clear date if observed_on_string blank" do
    @observation.observed_on.should_not be_blank
    @observation.update_attributes(:observed_on_string => "")
    @observation.observed_on.should be_blank
  end
  
  it "should set an iconic taxon if the taxon was set" do
    obs = Observation.make!
    obs.iconic_taxon.should be_blank
    taxon = Taxon.make!(:iconic_taxon => Taxon.make!(:is_iconic => true))
    taxon.iconic_taxon.should_not be_blank
    obs.taxon = taxon
    obs.save!
    obs.iconic_taxon.name.should == taxon.iconic_taxon.name
  end
  
  it "should remove an iconic taxon if the taxon was removed" do
    taxon = Taxon.make!(:iconic_taxon => Taxon.make!(:is_iconic => true))
    taxon.iconic_taxon.should_not be_blank
    obs = Observation.make!(:taxon => taxon)
    obs.iconic_taxon.should_not be_blank
    obs.taxon = nil
    obs.save!
    obs.reload
    obs.iconic_taxon.should be_blank
  end

  it "should queue refresh jobs for associated project lists if the taxon changed" do
    o = Observation.make!(:taxon => Taxon.make!)
    pu = ProjectUser.make!(:user => o.user)
    po = ProjectObservation.make!(:observation => o, :project => pu.project)
    Delayed::Job.delete_all
    stamp = Time.now
    o.update_attributes(:taxon => Taxon.make!)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    # puts jobs.map(&:handler).inspect
    jobs.select{|j| j.handler =~ /ProjectList.*refresh_with_observation/m}.should_not be_blank
  end
  
  it "should queue refresh job for check lists if the coordinates changed" do
    o = make_research_grade_observation
    Delayed::Job.delete_all
    stamp = Time.now
    o.update_attributes(:latitude => o.latitude + 1)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    # puts jobs.detect{|j| j.handler =~ /\:refresh_project_list\n/}.handler.inspect
    jobs.select{|j| j.handler =~ /CheckList.*refresh_with_observation/m}.should_not be_blank
  end

  it "should only queue one job to refresh life lists if taxon changed" do
    o = Observation.make!(:taxon => Taxon.make!)
    Delayed::Job.delete_all
    stamp = Time.now
    3.times do
      o.update_attributes(:taxon => Taxon.make!)
    end
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /LifeList.*refresh_with_observation/m}.size.should eq(1)
  end

  it "should only queue one job to refresh project lists if taxon changed" do
    po = make_project_observation(:taxon => Taxon.make!)
    o = po.observation
    Delayed::Job.delete_all
    stamp = Time.now
    3.times do
      o.update_attributes(:taxon => Taxon.make!)
    end
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /ProjectList.*refresh_with_observation/m}.size.should eq(1)
  end

  it "should only queue one check list refresh job" do
    o = make_research_grade_observation
    Delayed::Job.delete_all
    stamp = Time.now
    3.times do
      o.update_attributes(:latitude => o.latitude + 1)
    end
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    # puts jobs.detect{|j| j.handler =~ /\:refresh_project_list\n/}.handler.inspect
    jobs.select{|j| j.handler =~ /CheckList.*refresh_with_observation/m}.size.should eq(1)
  end
  
  it "should queue refresh job for check lists if the taxon changed" do
    o = make_research_grade_observation
    Delayed::Job.delete_all
    stamp = Time.now
    o.update_attributes(:taxon => Taxon.make!)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    pattern = /CheckList.*refresh_with_observation/m
    job = jobs.detect{|j| j.handler =~ pattern}
    job.should_not be_blank
    # puts job.handler.inspect
  end
  
  it "should queue refresh job for project lists if the taxon changed" do
    po = make_project_observation
    o = po.observation
    Delayed::Job.delete_all
    stamp = Time.now
    o.update_attributes(:taxon => Taxon.make!)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    pattern = /ProjectList.*refresh_with_observation/m
    job = jobs.detect{|j| j.handler =~ pattern}
    job.should_not be_blank
    # puts job.handler.inspect
  end
  
  it "should not allow impossible coordinates" do
    o = Observation.make!
    o.update_attributes(:latitude => 100)
    o.should_not be_valid
    
    o = Observation.make!
    o.update_attributes(:longitude => 200)
    o.should_not be_valid
    
    o = Observation.make!
    o.update_attributes(:latitude => -100)
    o.should_not be_valid
    
    o = Observation.make!
    o.update_attributes(:longitude => -200)
    o.should_not be_valid
  end
  
  describe "quality_grade" do
    it "should become research when it qualifies" do
      o = Observation.make!(:taxon => Taxon.make!, :latitude => 1, :longitude => 1)
      i = Identification.make!(:observation => o, :taxon => o.taxon)
      o.photos << LocalPhoto.make!(:user => o.user)
      o.reload
      o.quality_grade.should == Observation::CASUAL_GRADE
      o.update_attributes(:observed_on_string => "yesterday")
      o.quality_grade.should == Observation::RESEARCH_GRADE
    end
    
    it "should become casual when taxon changes" do
      o = make_research_grade_observation
      o.quality_grade.should == Observation::RESEARCH_GRADE
      new_taxon = Taxon.make!
      o.update_attributes(:taxon => new_taxon)
      o.quality_grade.should == Observation::CASUAL_GRADE
    end
    
    it "should become casual when date removed" do
      o = make_research_grade_observation
      o.quality_grade.should == Observation::RESEARCH_GRADE
      o.update_attributes(:observed_on_string => "")
      o.quality_grade.should == Observation::CASUAL_GRADE
    end

    it "should be research when community taxon is obs taxon and owner agrees" do
      o = make_research_grade_observation
      o.identifications.destroy_all
      o.reload
      parent = Taxon.make!(:rank => "genus")
      child = Taxon.make!(:parent => parent, :rank => "species")
      i1 = Identification.make!(:observation => o, :taxon => parent)
      i2 = Identification.make!(:observation => o, :taxon => child)
      i3 = Identification.make!(:observation => o, :taxon => child, :user => o.user)
      o.reload
      puts "o.num_identification_agreements: #{o.num_identification_agreements}"
      puts "o.num_identification_disagreements: #{o.num_identification_disagreements}"
      o.community_taxon.should eq child
      o.taxon.should eq child
      o.should be_community_supported_id
      o.should be_research_grade
    end

    it "should be casual if no identifications" do
      o = make_research_grade_observation
      o.identifications.destroy_all
      o.reload
      o.should be_casual_grade
    end
  end
  
  it "should queue a job to update user lists"
  it "should queue a job to update check lists"

  describe "obscuring for conservation status" do
    it "should obscure coordinates if taxon has a conservation status in the place observed" do
      p = make_place_with_geom
      t = Taxon.make!(:rank => Taxon::SPECIES)
      cs = ConservationStatus.make!(:place => p, :taxon => t)
      o = Observation.make!(:latitude => p.latitude, :longitude => p.longitude)
      o.should_not be_coordinates_obscured
      o.update_attributes(:taxon => t)
      o.should be_coordinates_obscured
    end

    it "should not obscure coordinates if taxon has a conservation status in another place" do
      p = make_place_with_geom
      t = Taxon.make!(:rank => Taxon::SPECIES)
      cs = ConservationStatus.make!(:place => p, :taxon => t)
      o = Observation.make!(:latitude => -1*p.latitude, :longitude => p.longitude)
      o.should_not be_coordinates_obscured
      o.update_attributes(:taxon => t)
      o.should_not be_coordinates_obscured
    end

    it "should obscure coordinates if locally threatened but globally secure" do
      p = make_place_with_geom
      t = Taxon.make!(:rank => Taxon::SPECIES)
      local_cs = ConservationStatus.make!(:place => p, :taxon => t)
      global_cs = ConservationStatus.make!(:taxon => t, :status => "LC", :iucn => Taxon::IUCN_LEAST_CONCERN, :geoprivacy => "open")
      o = Observation.make!(:latitude => p.latitude, :longitude => p.longitude)
      o.should_not be_coordinates_obscured
      o.update_attributes(:taxon => t)
      o.should be_coordinates_obscured
    end
  end

  it "should increment the taxon's counter cache" do
    o = Observation.make!
    t = Taxon.make!
    t.observations_count.should eq(0)
    o = without_delay {o.update_attributes(:taxon => t)}
    t.reload
    t.observations_count.should eq(1)
  end
  
  it "should increment the taxon's ancestors' counter caches" do
    o = Observation.make!
    p = Taxon.make!
    t = Taxon.make!(:parent => p)
    p.observations_count.should eq(0)
    o = without_delay {o.update_attributes(:taxon => t)}
    p.reload
    p.observations_count.should eq(1)
  end

  it "should decrement the taxon's counter cache" do
    t = Taxon.make!
    o = without_delay {Observation.make!(:taxon => t)}
    t.reload
    t.observations_count.should eq(1)
    o = without_delay {o.update_attributes(:taxon => nil)}
    t.reload
    t.observations_count.should eq(0)
  end
  
  it "should decrement the taxon's ancestors' counter caches" do
    p = Taxon.make!
    t = Taxon.make!(:parent => p)
    o = without_delay {Observation.make!(:taxon => t)}
    p.reload
    p.observations_count.should eq(1)
    o = without_delay {o.update_attributes(:taxon => nil)}
    p.reload
    p.observations_count.should eq(0)
  end
end

describe Observation, "destruction" do
  it "should decrement the counter cache in users" do
    @observation = Observation.make!
    user = @observation.user
    user.reload
    old_count = user.observations_count
    @observation.destroy
    user.reload
    user.observations_count.should == old_count - 1
  end
  
  it "should queue a DJ job to refresh lists" do
    Delayed::Job.delete_all
    stamp = Time.now
    Observation.make!(:taxon => Taxon.make!)
    jobs = Delayed::Job.all(:conditions => ["created_at >= ?", stamp])
    jobs.select{|j| j.handler =~ /List.*refresh_with_observation/m}.should_not be_blank
  end

  it "should delete associated updates" do
    subscriber = User.make!
    user = User.make!
    s = Subscription.make!(:user => subscriber, :resource => user)
    o = Observation.make(:user => user)
    without_delay { o.save! }
    update = Update.where(:subscriber_id => subscriber).last
    update.should_not be_blank
    o.destroy
    Update.find_by_id(update.id).should be_blank
  end

  it "should delete associated project observations" do
    po = make_project_observation
    o = po.observation
    o.destroy
    ProjectObservation.find_by_id(po.id).should be_blank
  end

  it "should decrement the taxon's counter cache" do
    t = Taxon.make!
    o = without_delay{Observation.make!(:taxon => t)}
    t.reload
    t.observations_count.should eq(1)
    o = without_delay {o.destroy}
    t.reload
    t.observations_count.should eq(0)
  end
  
  it "should decrement the taxon's ancestors' counter caches" do
    p = Taxon.make!
    t = Taxon.make!(:parent => p)
    o = without_delay {Observation.make!(:taxon => t)}
    p.reload
    p.observations_count.should eq(1)
    o = without_delay {o.destroy}
    p.reload
    p.observations_count.should eq(0)
  end

  it "should create a deleted observation" do
    o = Observation.make!
    o.destroy
    deleted_obs = DeletedObservation.where(:observation_id => o.id).first
    deleted_obs.should_not be_blank
    deleted_obs.user_id.should eq o.user_id
  end
end

describe Observation, "species_guess parsing" do
  before(:each) do
    @observation = Observation.make!
  end
  
  it "should choose a taxon if the guess corresponds to a unique taxon" do
    taxon = Taxon.make!
    @observation.taxon = nil
    @observation.species_guess = taxon.name
    @observation.save
    @observation.taxon_id.should == taxon.id
  end

  it "should choose a taxon from species_guess if exact matches form a subtree" do
    taxon = Taxon.make!(:rank => "species", :name => "Spirolobicus bananaensis")
    child = Taxon.make(:rank => "subspecies", :parent => taxon, :name => "#{taxon.name} foo")
    common_name = "Spiraled Banana Shrew"
    TaxonName.make!(:taxon => taxon, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    TaxonName.make!(:taxon => child, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    @observation.taxon = nil
    @observation.species_guess = common_name
    @observation.save
    @observation.taxon_id.should == taxon.id
  end

  it "should not choose a taxon from species_guess if exact matches don't form a subtree" do
    taxon = Taxon.make!(:rank => "species", :parent => Taxon.make!, :name => "Spirolobicus bananaensis")
    child = Taxon.make!(:rank => "subspecies", :parent => taxon, :name => "#{taxon.name} foo")
    taxon2 = Taxon.make!(:rank => "species", :parent => Taxon.make!)
    common_name = "Spiraled Banana Shrew"
    TaxonName.make!(:taxon => taxon, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    TaxonName.make!(:taxon => child, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    TaxonName.make!(:taxon => taxon2, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    child.ancestors.should include(taxon)
    child.ancestors.should_not include(taxon2)
    Taxon.includes(:taxon_names).where("taxon_names.name = ?", common_name).count.should eq(3)
    @observation.taxon = nil
    @observation.species_guess = common_name
    @observation.save
    @observation.taxon_id.should be_blank
  end

  it "should choose a taxon from species_guess if exact matches form a subtree regardless of case" do
    taxon = Taxon.make!(:rank => "species", :name => "Spirolobicus bananaensis")
    child = Taxon.make!(:rank => "subspecies", :parent => taxon, :name => "#{taxon.name} foo")
    common_name = "Spiraled Banana Shrew"
    TaxonName.make!(:taxon => taxon, :name => common_name.downcase, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    TaxonName.make!(:taxon => child, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
    @observation.taxon = nil
    @observation.species_guess = common_name
    @observation.save
    @observation.taxon_id.should == taxon.id
  end
  
  it "should not make a guess for problematic names" do
    Taxon::PROBLEM_NAMES.each do |name|
      t = Taxon.make!(:name => name.capitalize)
      o = Observation.make!(:species_guess => name)
      o.taxon_id.should_not == t.id
    end
  end
  
  it "should choose a taxon from a parenthesized scientific name" do
    name = "Northern Pygmy Owl (Glaucidium gnoma)"
    t = Taxon.make!(:name => "Glaucidium gnoma")
    o = Observation.make!(:species_guess => name)
    o.taxon_id.should == t.id
  end
  
  it "should choose a taxon from blah sp" do
    name = "Clarkia sp"
    t = Taxon.make!(:name => "Clarkia")
    o = Observation.make!(:species_guess => name)
    o.taxon_id.should == t.id
    
    name = "Clarkia sp."
    o = Observation.make!(:species_guess => name)
    o.taxon_id.should == t.id
  end
  
  it "should choose a taxon from blah ssp" do
    name = "Clarkia ssp"
    t = Taxon.make!(:name => "Clarkia")
    o = Observation.make!(:species_guess => name)
    o.taxon_id.should == t.id
    
    name = "Clarkia ssp."
    o = Observation.make!(:species_guess => name)
    o.taxon_id.should == t.id
  end

  it "should not make a guess if ends in a question mark" do
    t = Taxon.make!(:name => "Foo bar")
    o = Observation.make!(:species_guess => "#{t.name}?")
    o.taxon.should be_blank
  end
end

describe Observation, "named scopes" do
  before(:all) do
    load_test_taxa
  end
  # Valid UTC is something like:
  # '2008-01-01T01:00:00+00:00'
  # '2008-11-30T18:53:15+00:00'
  before(:each) do
    @after = 13.months.ago
    @before = 5.months.ago
    
    @after_formats = [@after, @after.iso8601]
    @before_formats = [@before, @before.iso8601]
    
    @amphibia = Taxon.find_by_name('Amphibia')
    @mollusca = Taxon.find_by_name('Mollusca')
    @pseudacris = Taxon.find_by_name('Pseudacris regilla')

    @pos = Observation.make!(
      :taxon => @pseudacris,
      :observed_on_string => '14 months ago',
      :id_please => true,
      :latitude => 20.01,
      :longitude => 20.01,
      :created_at => 14.months.ago,
      :time_zone => 'UTC'
    )
    
    @neg = Observation.make!(
      :taxon => @pseudacris,
      :observed_on_string => 'yesterday at 1pm',
      :latitude => 40,
      :longitude => 40,
      :time_zone => 'UTC'
    )
    
    @between = Observation.make!(
      :taxon => @pseudacris,
      :observed_on_string => '6 months ago',
      :created_at => 6.months.ago,
      :time_zone => 'UTC'
    )
    
    @aaron_saw_an_amphibian = Observation.make!(:taxon => @pseudacris)
    @aaron_saw_a_mollusk = Observation.make!(
      :taxon => @mollusca,
      :observed_on_string => '6 months ago',
      :created_at => 6.months.ago,
      :time_zone => 'UTC'
    )
    @aaron_saw_a_mystery = Observation.make!(
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

  it "should find observations in a bounding box in a year" do
    pos = Observation.make!(:latitude => @pos.latitude, :longitude => @pos.longitude, :observed_on_string => "2010-01-01")
    neg = Observation.make!(:latitude => @pos.latitude, :longitude => @pos.longitude, :observed_on_string => "2011-01-01")
    observations = Observation.in_bounding_box(20,20,30,30).on("2010")
    observations.map(&:id).should include(pos.id)
    observations.map(&:id).should_not include(neg.id)
  end

  it "should find observations in a bounding box spanning the date line" do
    pos = Observation.make!(:latitude => 0, :longitude => 179)
    neg = Observation.make!(:latitude => 0, :longitude => 170)
    observations = Observation.in_bounding_box(-1,178,1,-178)
    observations.map(&:id).should include(pos.id)
    observations.map(&:id).should_not include(neg.id)
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
    ObservationPhoto.make!(:observation => @pos)
    obs = Observation.has_photos.all
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
    observations = Observation.has_iconic_taxa(@mollusca)
    observations.should include(@aaron_saw_a_mollusk)
    observations.map(&:id).should_not include(@aaron_saw_an_amphibian.id)
  end
  
  it "should find observations in many iconic taxa" do
    observations = Observation.has_iconic_taxa(
      [@mollusca, @amphibia])
    observations.should include(@aaron_saw_a_mollusk)
    observations.should include(@aaron_saw_an_amphibian)
  end
  
  it "should find observations with NO iconic taxon" do
    observations = Observation.has_iconic_taxa(
      [@mollusca, nil])
    observations.should include(@aaron_saw_a_mollusk)
    observations.should include(@aaron_saw_a_mystery)
  end
  
  it "should order observations by created_at" do
    last_obs = Observation.make!
    Observation.order_by('created_at').to_a.last.should eq last_obs
  end
  
  it "should reverse order observations by created_at" do
    last_obs = Observation.make!
    Observation.order_by('created_at DESC').first.should eq last_obs
  end
  
  it "should not find anything for a non-existant taxon ID" do
    Observation.of(91919191).should be_empty
  end

  it "should not bail on invalid dates" do
    lambda {
      o = Observation.on("2013-02-30").all
    }.should_not raise_error
  end
end

describe Observation do
  describe "private coordinates" do
    before(:each) do
      @taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
    end
    
    it "should be set automatically if the taxon is threatened" do
      observation = Observation.make!(:taxon => @taxon, :latitude => 38, :longitude => -122)
      observation.taxon.should be_threatened
      observation.private_longitude.should_not be_blank
      observation.private_longitude.should_not == observation.longitude
    end
    
    it "should be set automatically if the taxon's parent is threatened" do
      child = Taxon.make!(:parent => @taxon, :rank => "subspecies")
      observation = Observation.make!(:taxon => child, :latitude => 38, :longitude => -122)
      observation.taxon.should_not be_threatened
      observation.private_longitude.should_not be_blank
      observation.private_longitude.should_not == observation.longitude
    end
    
    it "should be unset if the taxon changes to something unthreatened" do
      observation = Observation.make!(:taxon => @taxon, :latitude => 38, :longitude => -122)
      observation.taxon.should be_threatened
      observation.private_longitude.should_not be_blank
      observation.private_longitude.should_not == observation.longitude
      
      observation.update_attributes(:taxon => Taxon.make!)
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
        observation = Observation.make!(:place_guess => place_guess)
        observation.latitude.should_not be_blank
        observation.update_attributes(:taxon => @taxon)
        observation.place_guess.to_s.should == ""
      end
    end
    
    it "should not be included in json" do
      observation = Observation.make!(:taxon => @taxon, :latitude => 38.1234, :longitude => -122.1234)
      observation.to_json.should_not match(/private_latitude/)
    end
    
    it "should not be included in a json array" do
      observation = Observation.make!(:taxon => @taxon, :latitude => 38.1234, :longitude => -122.1234)
      Observation.make!
      observations = Observation.paginate(:page => 1, :per_page => 2, :order => "id desc")
      observations.to_json.should_not match(/private_latitude/)
    end

    it "should not be included in by_login_all csv generated for others" do
      observation = Observation.make!(:taxon => @taxon, :latitude => 38.1234, :longitude => -122.1234)
      Observation.make!
      path = Observation.generate_csv_for(observation.user)
      txt = open(path).read
      txt.should_not match(/private_latitude/)
      txt.should_not match(/#{observation.private_latitude}/)
    end

    it "should be visible to curators of projects to which the observation has been added" do
      po = make_project_observation
      o = po.observation
      o.update_attributes(:geoprivacy => Observation::PRIVATE, :latitude => 1, :longitude => 1)
      o.should be_coordinates_private
      pu = ProjectUser.make!(:project => po.project, :role => ProjectUser::CURATOR)
      o.coordinates_viewable_by?(pu.user).should be_true
    end

    it "should be visible to managers of projects to which the observation has been added" do
      po = make_project_observation
      o = po.observation
      o.update_attributes(:geoprivacy => Observation::PRIVATE, :latitude => 1, :longitude => 1)
      o.should be_coordinates_private
      pu = ProjectUser.make!(:project => po.project, :role => ProjectUser::MANAGER)
      o.coordinates_viewable_by?(pu.user).should be_true
    end
  end
  
  describe "obscure_coordinates" do
    it "should not affect observations without coordinates" do
      o = Observation.make!
      o.latitude.should be_blank
      o.obscure_coordinates
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
    
    it "should strip leading digits out of street addresses" do
      o = Observation.make!(:place_guess => '5720 Claremont Ave. Oakland, CA')
      o.obscure_coordinates
      o.place_guess.should_not match(/5720/)
      
      o = Observation.make!(:place_guess => '3333 23rd St, San Francisco, CA 94114, USA ')
      o.obscure_coordinates
      o.place_guess.should_not match(/3333/)

      o = Observation.make!(:place_guess => '3333A 23rd St, San Francisco, CA 94114, USA ')
      o.obscure_coordinates
      o.place_guess.should_not match(/3333/)
      
      o = Observation.make!(:place_guess => '3333-6666 23rd St, San Francisco, CA 94114, USA ')
      o.obscure_coordinates
      o.place_guess.should_not match(/3333/)
      o.place_guess.should_not match(/6666/)
    end
    
    it "should not affect already obscured coordinates" do
      o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::OBSCURED)
      lat = o.latitude
      private_lat = o.private_latitude
      o.should be_coordinates_obscured
      o.obscure_coordinates
      o.reload
      o.latitude.to_f.should == lat.to_f
      o.private_latitude.to_f.should == private_lat.to_f
    end
    
    it "should not affect already coordinates of a protected taxon" do
      o = make_observation_of_threatened
      lat = o.latitude
      private_lat = o.private_latitude
      o.should be_coordinates_obscured
      o.update_attributes(:geoprivacy => Observation::OBSCURED)
      o.reload
      o.latitude.to_f.should == lat.to_f
      o.private_latitude.to_f.should == private_lat.to_f
    end
    
  end
  
  describe "unobscure_coordinates" do
    it "should work" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      true_lat = 38.0
      true_lon = -122.0
      o = Observation.make!(:taxon => taxon, :latitude => true_lat, :longitude => true_lon)
      o.should be_coordinates_obscured
      o.latitude.to_f.should_not == true_lat
      o.longitude.to_f.should_not == true_lon
      o.unobscure_coordinates
      o.should_not be_coordinates_obscured
      o.latitude.to_f.should == true_lat
      o.longitude.to_f.should == true_lon
    end
    
    it "should not affect observations without coordinates" do
      o = Observation.make!
      o.latitude.should be_blank
      o.unobscure_coordinates
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
    
    it "should not obscure observations with obscured geoprivacy" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make!(:latitude => 38, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      o.unobscure_coordinates
      o.should be_coordinates_obscured
    end
    
    it "should not obscure observations with private geoprivacy" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make!(:latitude => 38, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.unobscure_coordinates
      o.should be_coordinates_obscured
      o.latitude.should be_blank
    end

  end
  
  describe "obscure_coordinates_for_observations_of" do
    it "should work" do
      taxon = Taxon.make!(:rank => "species")
      true_lat = 38.0
      true_lon = -122.0
      obs = []
      3.times do
        obs << Observation.make!(:taxon => taxon, :latitude => true_lat, :longitude => true_lon)
        obs.last.should_not be_coordinates_obscured
      end
      Observation.obscure_coordinates_for_observations_of(taxon)
      obs.each do |o|
        o.reload
        o.should be_coordinates_obscured
      end
    end
    
    it "should remove coordinates from place_guess" do
      taxon = Taxon.make!(:rank => "species")
      observation = Observation.make!(:place_guess => "38, -122", :taxon => taxon)
      observation.latitude.should_not be_blank
      Observation.obscure_coordinates_for_observations_of(taxon)
      observation.reload
      observation.place_guess.to_s.should == ""
    end
    
    it "should not affect observations without coordinates" do
      taxon = Taxon.make!(:rank => "species")
      o = Observation.make!(:taxon => taxon)
      o.latitude.should be_blank
      Observation.obscure_coordinates_for_observations_of(taxon)
      o.reload
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
    
    it "should not add coordinates to private observations" do
      taxon = Taxon.make!(:rank => "species")
      observation = Observation.make!(:place_guess => "38, -122", :taxon => taxon, :geoprivacy => Observation::PRIVATE)
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
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      true_lat = 38.0
      true_lon = -122.0
      obs = []
      3.times do
        obs << Observation.make!(:taxon => taxon, :latitude => true_lat, :longitude => true_lon)
        obs.last.should be_coordinates_obscured
      end
      Observation.unobscure_coordinates_for_observations_of(taxon)
      obs.each do |o|
        o.reload
        o.should_not be_coordinates_obscured
      end
    end
    
    it "should not affect observations without coordinates" do
      taxon = Taxon.make!(:rank => "species")
      o = Observation.make!(:taxon => taxon)
      o.latitude.should be_blank
      Observation.unobscure_coordinates_for_observations_of(taxon)
      o.reload
      o.latitude.should be_blank
      o.private_latitude.should be_blank
      o.longitude.should be_blank
      o.private_longitude.should be_blank
    end
    
    it "should not obscure observations with obscured geoprivacy" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make!(:latitude => 38, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      Observation.unobscure_coordinates_for_observations_of(taxon)
      o.reload
      o.should be_coordinates_obscured
    end
    
    it "should not obscure observations with private geoprivacy" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make!(:latitude => 38, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      Observation.unobscure_coordinates_for_observations_of(taxon)
      o.reload
      o.should be_coordinates_obscured
      o.latitude.should be_blank
    end

    it "should unobscure observations matching conservation status in a place"
    it "should not obscure observations not matching conservation status in a place"
  end

  describe "obscure_coordinates_for_threatened_taxa" do
    it "should not unobscure previously obscured observations of threatened taxa" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make!(:latitude => 38, :longitude => -122, :taxon => taxon)
      o.should be_coordinates_obscured
      o.obscure_coordinates_for_threatened_taxa
      o.should be_coordinates_obscured
    end

    it "should obscure coordinates for observations of taxa with concervation status in place"
    it "should not obscure coordinates for observations of taxa with concervation status of another place"
  end
  
  describe "geoprivacy" do
    it "should obscure coordinates when private" do
      o = Observation.make!(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.should be_coordinates_obscured
    end
    
    it "should remove public coordinates when private" do
      o = Observation.make!(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.latitude.should be_blank
      o.longitude.should be_blank
    end
    
    it "should remove public coordinates when private if coords change but not geoprivacy" do
      o = Observation.make!(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.update_attributes(:latitude => 1, :longitude => 1)
      o.should be_coordinates_obscured
      o.latitude.should be_blank
      o.longitude.should be_blank
    end
    
    it "should obscure coordinates when obscured" do
      o = Observation.make!(:latitude => 37, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      o.should be_coordinates_obscured
    end
    
    it "should not unobscure observations of threatened taxa" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make!(:taxon => taxon, :latitude => 37, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      o.should be_coordinates_obscured
      o.update_attributes(:geoprivacy => nil)
      o.geoprivacy.should be_blank
      o.should be_coordinates_obscured
    end
    
    it "should remove public coordinates when private even if taxon threatened" do
      taxon = Taxon.make!(:conservation_status => Taxon::IUCN_ENDANGERED, :rank => "species")
      o = Observation.make!(:latitude => 37, :longitude => -122, :taxon => taxon)
      o.should be_coordinates_obscured
      o.latitude.should_not be_blank
      o.update_attributes(:geoprivacy => Observation::PRIVATE)
      o.latitude.should be_blank
      o.longitude.should be_blank
    end
    
    it "should restore public coordinates when removing geoprivacy" do
      lat, lon = [37, -122]
      o = Observation.make!(:latitude => lat, :longitude => lon, :geoprivacy => Observation::PRIVATE)
      o.latitude.should be_blank
      o.longitude.should be_blank
      o.update_attributes(:geoprivacy => nil)
      o.latitude.to_f.should == lat
      o.longitude.to_f.should == lon
    end

    it "should be nil if not obscured or private" do
      o = Observation.make!(:geoprivacy => "open")
      o.geoprivacy.should be_nil
    end
  end
  
  describe "geom" do
    it "should be set with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.geom.should_not be_blank
    end
    
    it "should not be set without coords" do
      o = Observation.make!
      o.geom.should be_blank
    end
    
    it "should change with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.geom.y.should == 1.0
      o.update_attributes(:latitude => 2)
      o.geom.y.should == 2.0
    end
    
    it "should go away with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.update_attributes(:latitude => nil, :longitude => nil)
      o.geom.should be_blank
    end
  end

  describe "private_geom" do
    it "should be set with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.private_geom.should_not be_blank
    end
    
    it "should not be set without coords" do
      o = Observation.make!
      o.private_geom.should be_blank
    end
    
    it "should change with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.private_geom.y.should == 1.0
      o.update_attributes(:latitude => 2)
      o.private_geom.y.should == 2.0
    end
    
    it "should go away with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.update_attributes(:latitude => nil, :longitude => nil)
      o.private_geom.should be_blank
    end

    it "should be set with geoprivacy" do
      o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::OBSCURED)
      o.latitude.should_not eq 1.0
      o.private_latitude.should eq 1.0
      o.geom.y.should_not eq 1.0
      o.private_geom.y.should eq 1.0
    end

    it "should be set without geoprivacy" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.latitude.should eq 1.0
      o.private_geom.y.should eq 1.0
    end

    # it "should contain the private coordinates if geoprivacy" do

    # end
  end
  
  describe "query" do
    it "should filter by research grade" do
      r = make_research_grade_observation
      c = Observation.make!(:user => r.user)
      observations = Observation.query(:user => r.user, :quality_grade => Observation::RESEARCH_GRADE)
      observations.should include(r)
      observations.should_not include(c)
    end
  end
  
  it "should be georeferenced? even with private geoprivacy" do
    o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::PRIVATE)
    o.should be_georeferenced
  end
  
  describe "to_json" do
    it "should not include script tags" do
      o = Observation.make!(:description => "<script lang='javascript'>window.close()</script>")
      o.to_json.should_not match(/<script/)
      o.to_json(:viewer => o.user, 
        :force_coordinate_visibility => true,
        :include => [:user, :taxon, :iconic_taxon]).should_not match(/<script/)
      o = Observation.make!(:species_guess => "<script lang='javascript'>window.close()</script>")
      o.to_json.should_not match(/<script/)
    end
  end
  
end

describe Observation, "set_out_of_range" do
  before(:each) do
    @taxon = Taxon.make!
    @taxon_range = TaxonRange.make!(
      :taxon => @taxon, 
      :geom => MultiPolygon.from_ewkt("MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))")
    )
  end
  it "should set to false if observation intersects known range" do
    o = Observation.make!(:taxon => @taxon, :latitude => 0.5, :longitude => 0.5)
    o.set_out_of_range
    o.out_of_range.should == false
  end
  it "should set to true if observation does not intersect known range" do
    o = Observation.make!(:taxon => @taxon, :latitude => 2, :longitude => 2)
    o.set_out_of_range
    o.out_of_range.should == true
  end
  it "should set to null if observation does not have a taxon" do
    o = Observation.make!
    o.set_out_of_range
    o.out_of_range.should == nil
  end
  it "should set to null if taxon does not have a range" do
    t = Taxon.make!
    o = Observation.make!(:taxon => t)
    o.set_out_of_range
    o.out_of_range.should == nil
  end
end

describe Observation, "out_of_range" do
  it "should get set to false immediately if taxon set to nil" do
    o = Observation.make!(:taxon => Taxon.make!, :out_of_range => true)
    o.should be_out_of_range
    o.update_attributes(:taxon => nil)
    o.should_not be_out_of_range
  end
end

describe Observation, "license" do
  it "should use the user's default observation license" do
    u = User.make!
    u.preferred_observation_license = "CC-BY-NC"
    u.save
    o = Observation.make!(:user => u)
    o.license.should == u.preferred_observation_license
  end
  
  it "should update default license when requested" do
    u = User.make!
    u.preferred_observation_license.should be_blank
    o = Observation.make!(:user => u, :make_license_default => true, :license => Observation::CC_BY_NC)
    u.reload
    u.preferred_observation_license.should == Observation::CC_BY_NC
  end
  
  it "should update all other observations when requested" do
    u = User.make!
    o1 = Observation.make!(:user => u)
    o2 = Observation.make!(:user => u)
    o1.license.should be_blank
    o2.make_licenses_same = true
    o2.license = Observation::CC_BY_NC
    o2.save
    o1.reload
    o1.license.should == Observation::CC_BY_NC
  end
  
  it "should nilify if not a license" do
    o = Observation.make!(:license => Observation::CC_BY)
    o.update_attributes(:license => "on")
    o.reload
    o.license.should be_blank
  end
end

describe Observation, "places" do
  # need to switch from geometry to geography to really get this working
  # it "should work across the date line" do
  #   wkt = <<-WKT
  #     MULTIPOLYGON(((-152.09473 20.81363,-169.49708
  #     28.00992,-177.44019 30.24388,-179.52485 28.65781,141.65771
  #     25.45121,140.95458 18.32115,140.95458 10.02078,-170.39795
  #     -16.45927,-168.81592 -16.88025,-158.18116 0.44823,-152.09473
  #     20.81363)),((-152.09473 20.81363,-169.49708 28.00992,-177.44019
  #     30.24388,-179.52485 28.65781,141.65771 25.45121,140.95458
  #     18.32115,140.95458 10.02078,-170.39795 -16.45927,-168.81592
  #     -16.88025,-158.18116 0.44823,-152.09473 20.81363)),((-152.09473
  #     20.81363,-169.49708 28.00992,-177.44019 30.24388,-179.52485
  #     28.65781,141.65771 25.45121,140.95458 18.32115,140.95458
  #     10.02078,-170.39795 -16.45927,-168.81592 -16.88025,-158.18116
  #     0.44823,-152.09473 20.81363)))      
  #   WKT
  #   place = Place.make
  #   place.save_geom(MultiPolygon.from_ewkt(wkt))
  #   place.reload
  #   inside = Observation.make(:latitude => place.latitude, :longitude => place.longitude)
  #   inside.should be_georeferenced
  #   outside = Observation.make(:latitude => 24, :longitude => 92)
  #   outside.places.should_not include(place)
  #   inside.places.should include(place)
  # end
end

describe Observation, "update_stats" do
  it "should not consider outdated identifications as agreements" do
    o = Observation.make!(:taxon => Taxon.make!)
    old_ident = Identification.make!(:observation => o, :taxon => o.taxon)
    new_ident = Identification.make!(:observation => o, :user => old_ident.user)
    o.reload
    o.update_stats
    o.reload
    old_ident.reload
    old_ident.should_not be_current
    o.num_identification_agreements.should eq(0)
    o.num_identification_disagreements.should eq(1)
  end
end

describe Observation, "update_stats_for_observations_of" do
  it "should work" do
    parent = Taxon.make!
    child = Taxon.make!
    o = Observation.make!(:taxon => parent)
    i1 = Identification.make!(:observation => o, :taxon => child)
    o.reload
    o.num_identification_agreements.should eq(0)
    o.num_identification_disagreements.should eq(1)
    child.update_attributes(:parent => parent)
    Observation.update_stats_for_observations_of(parent)
    o.reload
    o.num_identification_agreements.should eq(1)
    o.num_identification_disagreements.should eq(0)
  end

  it "should work" do
    parent = Taxon.make!
    child = Taxon.make!
    o = Observation.make!(:taxon => parent)
    i1 = Identification.make!(:observation => o, :taxon => child)
    o.reload
    o.community_taxon.should be_blank
    child.update_attributes(:parent => parent)
    Observation.update_stats_for_observations_of(parent)
    o.reload
    o.community_taxon.should_not be_blank
  end
end

describe Observation, "nested observation_field_values" do
  it "should create a new record if ID set but existing not found" do
    ofv = ObservationFieldValue.make!
    of = ofv.observation_field
    o = ofv.observation
    attrs = {
      "observation_field_values_attributes" => {
        "0" => {
          "_destroy" => "false", 
          "observation_field_id" => ofv.observation_field_id, 
          "value" => ofv.value,
          "id" => ofv.id
        }
      }
    }
    ofv.destroy
    lambda { o.update_attributes(attrs) }.should_not raise_error(ActiveRecord::RecordNotFound)
    o.reload
    o.observation_field_values.last.observation_field_id.should eq(of.id)
  end

  it "should remove records if ID set but existing not found" do
    ofv = ObservationFieldValue.make!
    of = ofv.observation_field
    o = ofv.observation
    attrs = {
      "observation_field_values_attributes" => {
        "0" => {
          "_destroy" => "true", 
          "observation_field_id" => ofv.observation_field_id, 
          "value" => ofv.value,
          "id" => ofv.id
        }
      }
    }
    ofv.destroy
    lambda { o.update_attributes(attrs) }.should_not raise_error(ActiveRecord::RecordNotFound)
    o.reload
    o.observation_field_values.should be_blank
  end
end

describe Observation, "taxon updates" do
  it "should generate an update" do
    t = Taxon.make!
    s = Subscription.make!(:resource => t)
    o = Observation.make(:taxon => t)
    without_delay do
      o.save!
    end
    u = Update.last
    u.should_not be_blank
    u.notifier.should eq(o)
    u.subscriber.should eq(s.user)
  end

  it "should generate an update for descendent taxa" do
    t1 = Taxon.make!
    t2 = Taxon.make!(:parent => t1)
    s = Subscription.make!(:resource => t1)
    o = Observation.make(:taxon => t2)
    without_delay do
      o.save!
    end
    u = Update.last
    u.should_not be_blank
    u.notifier.should eq(o)
    u.subscriber.should eq(s.user)
  end
end

describe Observation, "update_for_taxon_change" do
  before(:each) do
    @taxon_swap = TaxonSwap.make
    @input_taxon = Taxon.make!
    @output_taxon = Taxon.make!
    @taxon_swap.add_input_taxon(@input_taxon)
    @taxon_swap.add_output_taxon(@output_taxon)
    @taxon_swap.save!
    @obs_of_input = Observation.make!(:taxon => @input_taxon)
  end

  it "should add new identifications" do
    @obs_of_input.identifications.size.should eq(1)
    @obs_of_input.identifications.first.taxon.should eq(@input_taxon)
    Observation.update_for_taxon_change(@taxon_swap, @output_taxon)
    @obs_of_input.reload
    @obs_of_input.identifications.size.should eq(2)
    @obs_of_input.identifications.detect{|i| i.taxon_id == @output_taxon.id}.should_not be_blank
  end

  it "should not update old identifications" do
    old_ident = @obs_of_input.identifications.first
    old_ident.taxon.should eq(@input_taxon)
    Observation.update_for_taxon_change(@taxon_swap, @output_taxon)
    old_ident.reload
    old_ident.taxon.should eq(@input_taxon)
  end
end

describe Observation, "reassess_coordinates_for_observations_of" do
  it "should obscure coordinates for observations of threatened taxa" do
    t = Taxon.make!
    o = Observation.make!(:taxon => t, :latitude => 1, :longitude => 1)
    cs = ConservationStatus.make!(:taxon => t)
    o.should_not be_coordinates_obscured
    Observation.reassess_coordinates_for_observations_of(t)
    o.reload
    o.should be_coordinates_obscured
  end
  
  it "should not unobscure coordinates of obs of unthreatened if geoprivacy is set" do
    t = Taxon.make!
    o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::OBSCURED, :taxon => t)
    old_lat = o.latitude
    o.should be_coordinates_obscured
    Observation.reassess_coordinates_for_observations_of(t)
    o.reload
    o.should be_coordinates_obscured
    o.latitude.should eq(old_lat)
  end
end

describe Observation, "queue_for_sharing" do
  it "should queue a job if twitter ProviderAuthorization present" do
    pa = ProviderAuthorization.make!(:provider_name => "twitter")
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_twitter%"]).should be_blank
    o = Observation.make!(:user => pa.user)
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_twitter%"]).should_not be_blank
  end
  it "should queue a job if facebook ProviderAuthorization present" do
    pa = ProviderAuthorization.make!(:provider_name => "facebook")
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_facebook%"]).should be_blank
    o = Observation.make!(:user => pa.user)
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_facebook%"]).should_not be_blank
  end
  it "should not queue a job if no ProviderAuthorizations present" do
    o = Observation.make!
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_facebook%"]).should be_blank
  end
  it "should not queue a twitter job if twitter_sharing is 0" do
    pa = ProviderAuthorization.make!(:provider_name => "twitter")
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_twitter%"]).should be_blank
    o = Observation.make!(:user => pa.user, :twitter_sharing => "0")
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_twitter%"]).should be_blank
  end
  it "should not queue a facebook job if facebook_sharing is 0" do
    pa = ProviderAuthorization.make!(:provider_name => "facebook")
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_facebook%"]).should be_blank
    o = Observation.make!(:user => pa.user, :facebook_sharing => "0")
    Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_facebook%"]).should be_blank
  end
end

describe Observation, "captive" do
  it "should vote yes on the wild quality metric if 1" do
    o = Observation.make!(:captive_flag => "1")
    o.quality_metrics.should_not be_blank
    o.quality_metrics.first.user.should eq(o.user)
    o.quality_metrics.first.should_not be_agree
  end

  it "should vote no on the wild quality metric if 0 and metric exists" do
    o = Observation.make!(:captive_flag => "1")
    o.quality_metrics.should_not be_blank
    o.update_attributes(:captive_flag => "0")
    o.quality_metrics.first.should be_agree
  end

  it "should not alter quality metrics if nil" do
    o = Observation.make!(:captive_flag => nil)
    o.quality_metrics.should be_blank
  end

  it "should not alter quality metrics if 0 and not metrics exist" do
    o = Observation.make!(:captive_flag => "0")
    o.quality_metrics.should be_blank
  end
end

describe Observation, "merge" do
  let(:user) { User.make! }
  let(:reject) { Observation.make!(:user => user) }
  let(:keeper) { Observation.make!(:user => user) }
  
  it "should destroy the reject" do
    keeper.merge(reject)
    Observation.find_by_id(reject.id).should be_blank
  end

  it "should preserve photos" do
    op = ObservationPhoto.make!(:observation => reject)
    keeper.merge(reject)
    op.reload
    op.observation.should eq(keeper)
  end

  it "should preserve comments" do
    c = Comment.make!(:parent => reject)
    keeper.merge(reject)
    c.reload
    c.parent.should eq(keeper)
  end

  it "should preserve identifications" do
    i = Identification.make!(:observation => reject)
    keeper.merge(reject)
    i.reload
    i.observation.should eq(keeper)
  end

  it "should mark duplicate identifications as not current" do
    t = Taxon.make!
    without_delay do
      reject.update_attributes(:taxon => t)
      keeper.update_attributes(:taxon => t)
    end
    keeper.merge(reject)
    idents = keeper.identifications.where(:user_id => keeper.user_id).order('id asc')
    idents.size.should eq(2)
    idents.first.should_not be_current
    idents.last.should be_current
  end
end

describe Observation, "component_cache_key" do
  it "should be the same regardless of option order" do
    k1 = Observation.component_cache_key(111, :for_owner => true, :locale => :en)
    k2 = Observation.component_cache_key(111, :locale => :en, :for_owner => true)
    k1.should eq(k2)
  end
end

describe Observation, "dynamic taxon getters" do
  it "should not interfere with taxon_id"
  it "should return genus"
end

describe Observation, "dynamic place getters" do
  it "should return place state" do
    p = make_place_with_geom(:place_type => Place::PLACE_TYPE_CODES['State'])
    o = Observation.make!(:latitude => p.latitude, :longitude => p.longitude)
    o.intersecting_places.should_not be_blank
    o.place_state.should eq p
    o.place_state_name.should eq p.name
  end
end

describe Observation, "community taxon" do

  it "should be set if user has opted out" do
    u = User.make!(:prefers_community_taxa => false)
    o = Observation.make!(:user => u)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.community_taxon.should_not be_blank
  end

  it "should be set if user has opted out and community agrees with user" do
    u = User.make!(:prefers_community_taxa => false)
    o = Observation.make!(:taxon => Taxon.make!, :user => u)
    i1 = Identification.make!(:observation => o, :taxon => o.taxon)
    o.reload
    o.community_taxon.should eq o.taxon
  end

  it "should be set if observation is opted out" do
    o = Observation.make!(:prefers_community_taxon => false)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.community_taxon.should_not be_blank
  end

  it "should be set if observation is opted in but user is opted out" do
    u = User.make!(:prefers_community_taxa => false)
    o = Observation.make!(:prefers_community_taxon => true, :user => u)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.community_taxon.should eq i1.taxon
  end

  it "should be set when preference set to true" do
    o = Observation.make!(:prefers_community_taxon => false)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.taxon.should be_blank
    o.update_attributes(:prefers_community_taxon => true)
    o.reload
    o.community_taxon.should eq(i1.taxon)
  end

  it "should not be unset when preference set to false" do
    o = Observation.make!
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.community_taxon.should eq(i1.taxon)
    o.update_attributes(:prefers_community_taxon => false)
    o.reload
    o.community_taxon.should_not be_blank
  end

  it "should set the taxon" do
    o = Observation.make!
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.taxon.should eq o.community_taxon
  end

  it "should set the species_guess" do
    o = Observation.make!
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.species_guess.should eq o.community_taxon.name
  end

  it "should set the iconic taxon" do
    o = Observation.make!
    o.iconic_taxon.should be_blank
    iconic_taxon = Taxon.make!(:is_iconic => true, :rank => "family")
    i1 = Identification.make!(:observation => o, :taxon => Taxon.make!(:parent => iconic_taxon, :rank => "genus"))
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    i1.taxon.iconic_taxon.should eq iconic_taxon
    o.reload
    o.taxon.should eq i1.taxon
    o.iconic_taxon.should eq iconic_taxon
  end

  it "should not set the taxon if the user has opted out" do
    u = User.make!(:prefers_community_taxa => false)
    o = Observation.make!(:user => u)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.taxon.should be_blank
  end

  it "should not set the taxon if the observation is opted out" do
    o = Observation.make!(:prefers_community_taxon => false)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.taxon.should be_blank
  end

  it "should change the taxon to the owner's identication when observation opted out" do
    owner_taxon = Taxon.make!
    o = Observation.make!(:taxon => owner_taxon)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.community_taxon.should eq(i1.taxon)
    o.taxon.should eq o.community_taxon
    o.update_attributes(:prefers_community_taxon => false)
    o.reload
    o.taxon.should eq owner_taxon
  end

  it "should set the species_guess when opted out" do
    owner_taxon = Taxon.make!
    o = Observation.make!(:taxon => owner_taxon)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.community_taxon.should eq(i1.taxon)
    o.taxon.should eq o.community_taxon
    o.update_attributes(:prefers_community_taxon => false)
    o.reload
    o.species_guess.should eq owner_taxon.name
  end

  it "should set the taxon if observation is opted in but user is opted out" do
    u = User.make!(:prefers_community_taxa => false)
    o = Observation.make!(:prefers_community_taxon => true, :user => u)
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
    o.reload
    o.taxon.should eq o.community_taxon
  end

  it "should not be set if there is only one current identification" do
    o = Observation.make!
    i1 = Identification.make!(:observation => o, :user => o.user)
    i2 = Identification.make!(:observation => o, :user => o.user)
    o.reload
    o.community_taxon.should be_blank
  end

  it "should not be set for 2 roots" do
    o = Observation.make!
    i1 = Identification.make!(:observation => o)
    i2 = Identification.make!(:observation => o)
    o.reload
    o.community_taxon.should be_blank
  end

  it "change should be triggered by changing the taxon" do
    o = Observation.make!
    i1 = Identification.make!(:observation => o)
    o.reload
    o.community_taxon.should be_blank
    o.update_attributes(:taxon => i1.taxon)
    o.community_taxon.should_not be_blank
  end

  # it "change should trigger change in observation stats" do

  # end

  describe "test cases: " do
    before do
      # Tree:
      #          f
      #       /     \
      #      g1     g2
      #     /  \
      #    s1  s2
      #   /  \
      # ss1  ss2

      @f = Taxon.make!(:rank => "family", :name => "f")
      @g1 = Taxon.make!(:rank => "genus", :parent => @f, :name => "g1")
      @g2 = Taxon.make!(:rank => "genus", :parent => @f, :name => "g2")
      @s1 = Taxon.make!(:rank => "species", :parent => @g1, :name => "s1")
      @s2 = Taxon.make!(:rank => "species", :parent => @g1, :name => "s2")
      @ss1 = Taxon.make!(:rank => "species", :parent => @s1, :name => "ss1")
      @ss2 = Taxon.make!(:rank => "species", :parent => @s1, :name => "ss2")
      @o = Observation.make!
    end

    it "s1 s1 s2" do
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @s1)
      i = Identification.make!(:observation => @o, :taxon => @s2)
      @o.reload
      @o.community_taxon.should eq @g1
    end

    it "s1 s1 g1" do
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @g1)
      @o.reload
      @o.community_taxon.should eq @g1
    end

    it "s1 s1 s1 g1" do
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @g1)
      @o.reload
      @o.community_taxon.should eq @s1
    end

    it "ss1 ss1 ss2 ss2" do
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @s2)
      @o.reload
      @o.community_taxon.should eq @g1
    end

    it "f f f f ss1 s2 s2 s2 s2" do
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @ss1)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @s2)
      @o.reload
      @o.community_taxon.should eq @s2
    end

    it "f f f f ss1 ss1 s2 s2 s2 s2 g1" do
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @ss1)
      Identification.make!(:observation => @o, :taxon => @ss1)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @s2)
      Identification.make!(:observation => @o, :taxon => @g1)
      @o.reload
      @o.community_taxon.should eq @g1
    end

    it "f g1 s1 (should not taxa with only one ID to be the community taxon)" do
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @g1)
      Identification.make!(:observation => @o, :taxon => @s1)
      @o.reload
      @o.community_taxon.should eq @g1
    end

    it "f f g1 s1" do
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @g1)
      Identification.make!(:observation => @o, :taxon => @s1)
      @o.reload
      @o.community_taxon.should eq @g1
    end

    it "s1 s1 f f" do
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @s1)
      Identification.make!(:observation => @o, :taxon => @f)
      Identification.make!(:observation => @o, :taxon => @f)
      @o.reload
      @o.community_taxon.should eq @f
    end
  end
end

