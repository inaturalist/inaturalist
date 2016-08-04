# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Observation do
  before(:all) do
    DatabaseCleaner.clean_with(:truncation, except: %w[spatial_ref_sys])
  end

  before(:each) { enable_elastic_indexing( Observation, Taxon ) }
  after(:each) { disable_elastic_indexing( Observation, Taxon ) }

  describe "creation" do

    before(:each) do
      @taxon = Taxon.make!
      @observation = Observation.make!(:taxon => @taxon, :observed_on_string => 'yesterday at 1pm')
    end
  
    it "should be in the past" do
      expect(@observation.observed_on).to be <= Date.today
    end
  
    it "should not be in the future" do
      expect {
        Observation.make!(:observed_on_string => '2 weeks from now')
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  
    it "should properly set date and time" do
      Time.use_zone(@observation.time_zone) do
        expect(@observation.observed_on).to eq 1.day.ago.to_date
        expect(@observation.time_observed_at.hour).to eq 13
      end
    end
  
    it "should parse time from strings like October 30, 2008 10:31PM" do
      @observation.observed_on_string = 'October 30, 2008 10:31PM'
      @observation.save
      expect(@observation.time_observed_at.in_time_zone(@observation.time_zone).hour).to eq 22
    end
  
    it "should parse time from strings like 2011-12-23T11:52:06-0500" do
      @observation.observed_on_string = '2011-12-23T11:52:06-0500'
      @observation.save
      expect(@observation.time_observed_at.in_time_zone(@observation.time_zone).hour).to eq 11
    end
  
    it "should parse time from strings like 2011-12-23T11:52:06.123" do
      @observation.observed_on_string = '2011-12-23T11:52:06.123'
      @observation.save
      expect(@observation.time_observed_at.in_time_zone(@observation.time_zone).hour).to eq 11
    end
  
    it "should parse time and zone from July 9, 2012 7:52:39 AM ACST" do
      @observation.observed_on_string = 'July 9, 2012 7:52:39 AM ACST'
      @observation.save
      expect(@observation.time_observed_at.in_time_zone(@observation.time_zone).hour).to eq 7
      expect(@observation.time_zone).to eq ActiveSupport::TimeZone['Adelaide'].name
    end

    it "should parse a bunch of test date strings" do
      [
        ['Fri Apr 06 2012 16:23:35 GMT-0500 (GMT-05:00)', {:month => 4, :day => 6, :hour => 16, :offset => "-05:00"}],
        ['Sun Nov 03 2013 08:15:25 GMT-0500 (GMT-5)', {:month => 11, :day => 3, :hour => 8, :offset => "-05:00"}],

        # This won't work given our current setup because if we lookup a time
        # zone by offset like this, it will return the first *named* timezone,
        # which in this case is Amsterdam, which is the same as CET, which, in
        # September, observes daylight savings time, so it's actually CEST and
        # the offset is +2:00. The main problem here is that if the client just
        # specifies an offset, we can't reliably find the zone
        # ['September 27, 2012 8:09:50 AM GMT+01:00', :month => 9, :day => 27, :hour => 8, :offset => "+01:00"],

        # This *does* work b/c in December, Amsterdam is in CET, standard time
        ['December 27, 2012 8:09:50 AM GMT+01:00', :month => 12, :day => 27, :hour => 8, :offset => "+01:00"],

        ['Thu Dec 26 2013 11:18:22 GMT+0530 (GMT+05:30)', :month => 12, :day => 26, :hour => 11, :offset => "+05:30"],
        ['2010-08-23 13:42:55 +0000', :month => 8, :day => 23, :hour => 13, :offset => "+00:00"],
        ['2014-06-18 5:18:17 pm CEST', :month => 6, :day => 18, :hour => 17, :offset => "+02:00"]
      ].each do |date_string, opts|
        o = Observation.make!(:observed_on_string => date_string)
        expect(o.observed_on.day).to eq opts[:day]
        expect(o.observed_on.month).to eq opts[:month]
        t = o.time_observed_at.in_time_zone(o.time_zone)
        expect(t.hour).to eq opts[:hour]
        expect(t.formatted_offset).to eq opts[:offset]
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
        expect(zone.formatted_offset).to eq opts[:offset]
        expect(o.observed_on.month).to eq opts[:month]
        expect(o.observed_on.day).to eq opts[:day]
        expect(o.time_observed_at.in_time_zone(o.time_zone).hour).to eq opts[:hour]
      end
    end
  
    it "should parse a time zone from a code" do
      @observation.observed_on_string = 'October 30, 2008 10:31PM EST'
      @observation.save
      expect(@observation.time_zone).to eq ActiveSupport::TimeZone['Eastern Time (US & Canada)'].name
    end
  
    it "should parse time zone from strings like 2011-12-23T11:52:06-0500" do
      @observation.observed_on_string = '2011-12-23T11:52:06-0500'
      @observation.save
      zone = ActiveSupport::TimeZone[@observation.time_zone]
      expect(zone).not_to be_blank
      expect(zone.formatted_offset).to eq "-05:00"
    end

    it "should handle unparsable times gracefully" do
      @observation.observed_on_string = "2013-03-02, 1430hrs"
      @observation.save
      expect(@observation).to be_valid
      expect(@observation.observed_on.day).to eq 2
    end
  
    it "should not save a time if one wasn't specified" do
      @observation.observed_on_string = "April 2 2008"
      @observation.save
      expect(@observation.time_observed_at).to be_blank
    end
  
    it "should not save a time for 'today' or synonyms" do
      @observation.observed_on_string = "today"
      @observation.save
      expect(@observation.time_observed_at).to be(nil)
    end

    it "should not choke of bad dates" do
      @observation.observed_on_string = "this is not a date"
      expect {
        @observation.save
      }.not_to raise_error
    end
  
    it "should have an identification if taxon is known" do
      @observation.save
      @observation.reload
      expect(@observation.identifications.empty?).not_to be(true)
    end
  
    it "should not have an identification if taxon is not known" do
      o = Observation.make!
      expect(o.identifications.to_a).to be_blank
    end
  
    it "should have an identification that matches the taxon" do
      @observation.reload
      expect(@observation.identifications.first.taxon).to eq @observation.taxon
    end
  
    it "should queue a DJ job to refresh lists" do
      Delayed::Job.delete_all
      stamp = Time.now
      Observation.make!(:taxon => Taxon.make!)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /List.*refresh_with_observation/m}).not_to be_blank
    end
  
    it "should properly parse relative datetimes like '2 days ago'" do
      Time.use_zone(@observation.user.time_zone) do
        @observation.observed_on_string = '2 days ago'
        @observation.save
        expect(@observation.observed_on).to eq 2.days.ago.to_date
      end
    end
  
    it "should not save relative dates/times like 'yesterday'" do
      expect(@observation.observed_on_string.split.include?('yesterday')).to be(false)
    end
  
    it "should not save relative dates/times like 'this morning'" do
      @observation.observed_on_string = 'this morning'
      @observation.save
      @observation.reload
      expect(@observation.observed_on_string.match('this morning')).to be(nil)
    end
  
    it "should preserve observed_on_string if it did NOT contain a relative " +
       "time descriptor" do
      @observation.observed_on_string = "April 22 2008"
      @observation.save
      @observation.reload
      expect(@observation.observed_on_string).to eq "April 22 2008"
    end
  
    it "should parse dates that contain commas" do
      @observation.observed_on_string = "April 22, 2008"
      @observation.save
      expect(@observation.observed_on).not_to be(nil)
    end
  
    it "should NOT parse a date like '2004'" do
      @observation.observed_on_string = "2004"
      @observation.save
      expect(@observation).not_to be_valid
    end
  
    it "should default to the user's time zone" do
      expect(@observation.time_zone).to eq @observation.user.time_zone
    end
  
    it "should NOT use the user's time zone if another was set" do
      @observation.time_zone = 'Eastern Time (US & Canada)'
      @observation.save
      expect(@observation).to be_valid
      @observation.reload
      expect(@observation.time_zone).not_to eq @observation.user.time_zone
      expect(@observation.time_zone).to eq'Eastern Time (US & Canada)'
    end
  
    it "should save the time in the time zone selected" do
      @observation.time_zone = 'Eastern Time (US & Canada)'
      @observation.save
      expect(@observation).to be_valid
      expect(@observation.time_observed_at.in_time_zone(@observation.time_zone).hour).to eq 13
    end
  
    it "should set the time zone to UTC if the user's time zone is blank" do
      u = User.make!
      u.update_attribute(:time_zone, nil)
      expect(u.time_zone).to be_blank
      o = Observation.new(:user => u)
      o.save
      expect(o.time_zone).to eq'UTC'
    end
  
    it "should trim whitespace from species_guess" do
      @observation.species_guess = " Anna's Hummingbird     "
      @observation.save
      expect(@observation.species_guess).to eq "Anna's Hummingbird"
    end
  
    it "should increment the counter cache in users" do
      old_count = @observation.user.observations_count
      Observation.make!(:user => @observation.user)
      @observation.reload
      expect(@observation.user.observations_count).to eq old_count+1
    end
  
    it "should allow lots of sigfigs" do
      lat =  37.91143999
      lon = -122.2687819
      @observation.latitude = lat
      @observation.longitude = lon
      @observation.save
      @observation.reload
      expect(@observation.latitude.to_f).to eq lat
      expect(@observation.longitude.to_f).to eq lon
    end
  
    it "should set lat/lon if entered in place_guess" do
      lat =  37.91143999
      lon = -122.2687819
      expect(@observation.latitude).to be_blank
      @observation.place_guess = "#{lat}, #{lon}"
      @observation.save
      expect(@observation.latitude.to_f).to eq lat
      expect(@observation.longitude.to_f).to eq lon
    end
  
    it "should set lat/lon if entered in place_guess as NSEW" do
      lat =  -37.91143999
      lon = -122.2687819
      expect(@observation.latitude).to be_blank
      @observation.place_guess = "S#{lat * -1}, W#{lon * -1}"
      @observation.save
      expect(@observation.latitude.to_f).to eq lat
      expect(@observation.longitude.to_f).to eq lon
    end
  
    it "should not set lat/lon for addresses with numbers" do
      o = Observation.make!(:place_guess => "Apt 1, 33 Figueroa Ave., Somewhere, CA")
      expect(o.latitude).to be_blank
    end
  
    it "should not set lat/lon for addresses with zip codes" do
      o = Observation.make!(:place_guess => "94618")
      expect(o.latitude).to be_blank
      o = Observation.make!(:place_guess => "94618-5555")
      expect(o.latitude).to be_blank
    end

    describe "place_guess" do
      let( :big_place ) do
        make_place_with_geom(
          wkt: "MULTIPOLYGON(((1 1,1 2,2 2,2 1,1 1)))",
          admin_level: Place::COUNTRY_LEVEL,
          name: "Big Place"
        )
      end
      let( :small_place ) do
        make_place_with_geom( 
          # wkt: "MULTIPOLYGON(((1.2 1.2,1.2 1.8,1.8 1.8,1.8 1.2,1.2 1.2)))", 
          wkt: "MULTIPOLYGON(((1.3 1.3,1.3 1.7,1.7 1.7,1.7 1.3,1.3 1.3)))", 
          parent: big_place,
          admin_level: Place::STATE_LEVEL,
          name: "Small Place"
        )
      end
      let( :user_place ) do
        make_place_with_geom( 
          wkt: "MULTIPOLYGON(((1.4 1.4,1.4 1.6,1.6 1.6,1.6 1.4,1.4 1.4)))", 
          parent: small_place,
          name: "User Place"
        )
      end
      it "should be set based on coordinates" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        expect( o.place_guess ).to match /#{ small_place.name }/
      end
      it "should not change the coordinates when set based on coordinates" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        expect( o.latitude ).to eq small_place.latitude
        expect( o.longitude ).to eq small_place.longitude
      end
      it "should not be set without coordinates" do
        o = Observation.make!
        expect( o.latitude ).to be_blank
        expect( o.place_guess ).to be_blank
      end
      it "should not be set if already set" do
        o = Observation.make!(
          latitude: small_place.latitude, 
          longitude: small_place.longitude, 
          place_guess: "Copperopolis"
        )
        expect( o.place_guess ).to eq "Copperopolis"
      end
      it "should include places with admin_level" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        expect( o.place_guess ).to match /#{ small_place.name }/
        expect( o.place_guess ).to match /#{ big_place.name }/
      end
      it "should not include places without admin_level" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        expect( user_place.admin_level ).to be_blank
        expect( o.place_guess ).not_to match /#{ user_place.name }/
      end

      it "should only use places that contain the public_positional_accuracy" do
        swlat, swlng, nelat, nelng = small_place.bounding_box

        place_left_side = lat_lon_distance_in_meters(swlat, swlng, nelat, swlng)
        o = Observation.make!(
          latitude: small_place.latitude,
          longitude: small_place.longitude,
          positional_accuracy: place_left_side + 10
        )
        expect( big_place ).to be_bbox_contains_lat_lng_acc(
          o.latitude,
          o.longitude,
          o.positional_accuracy
        )
        expect( small_place ).not_to be_bbox_contains_lat_lng_acc(
          o.latitude,
          o.longitude,
          o.positional_accuracy
        )
        expect( o.place_guess ).not_to match /#{ small_place.name }/
        expect( o.place_guess ).to match /#{ big_place.name }/
      end
      it "should use codes when available" do
        big_place.update_attributes(code: "USA")
        o = Observation.make!(latitude: small_place.latitude, longitude: small_place.longitude)
        expect( o.place_guess ).to match /#{ big_place.code }/
        expect( o.place_guess ).not_to match /#{ big_place.name }/
      end
      it "should use names translated for the observer" do
        big_place.update_attributes( name: "Mexico" )
        user = User.make!( locale: "es-MX" )
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude, user: user )
        expect( o.place_guess ).to match /#{ I18n.t( big_place.name, locale: user.locale ) }/
      end
    end
  
    describe "quality_grade" do
      it "should default to casual" do
        o = Observation.make!
        expect(o.quality_grade).to eq Observation::CASUAL
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
      expect(o.user_agent.size).to be < 256
    end

    it "should set the URI" do
      o = Observation.make!
      o.reload
      expect(o.uri).to eq(FakeView.observation_url(o))
    end

    it "should not set the URI if already set" do
      uri = "http://www.somewhereelse.com/users/4"
      o = Observation.make!(:uri => uri)
      o.reload
      expect(o.uri).to eq(uri)
    end

    it "should increment the taxon's counter cache" do
      t = without_delay { Taxon.make! }
      expect(t.observations_count).to eq 0
      o = without_delay { Observation.make!(:taxon => t) }
      t.reload
      expect(t.observations_count).to eq 1
    end

    it "should increment the taxon's ancestors' counter caches" do
      p = without_delay { Taxon.make! }
      t = without_delay { Taxon.make!(:parent => p) }
      expect(p.observations_count).to eq 0
      o = without_delay { Observation.make!(:taxon => t) }
      p.reload
      expect(p.observations_count).to eq 1
    end

    it "should be georeferenced? with zero degrees" do
      expect( Observation.make!(longitude: 0, latitude: 0) ).to be_georeferenced
    end

    it "should not be georeferenced with nil degrees" do
      expect( Observation.make!(longitude: 0, latitude: nil) ).not_to be_georeferenced
    end

    it "should be georeferenced? even with private geoprivacy" do
      o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::PRIVATE)
      expect(o).to be_georeferenced
    end

  end

  describe "updating" do
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
      expect(Identification.find_by_id(old_owners_ident.id)).not_to be_blank
    end

    it "should not destroy the owner's old identification if the taxon has changed unless it's the owner's only identification" do
      t1 = Taxon.make!
      o = Observation.make!(:taxon => t1)
      old_owners_ident = o.identifications.detect{|ident| ident.user_id == o.user_id}
      o.update_attributes(:taxon => nil)
      o.reload
      expect(Identification.find_by_id(old_owners_ident.id)).to be_blank
    end
  
    it "should properly set date and time" do
      @observation.save
      @observation.observed_on_string = 'March 16 2007 at 2pm'
      @observation.save
      expect(@observation.observed_on).to eq Date.parse('2007-03-16')
      expect(@observation.time_observed_at_in_zone.hour).to eq(14)
    end
  
    it "should not save a time if one wasn't specified" do
      @observation.update_attributes(:observed_on_string => "April 2 2008")
      @observation.save
      expect(@observation.time_observed_at).to be_blank
    end
  
    it "should clear date if observed_on_string blank" do
      expect(@observation.observed_on).not_to be_blank
      @observation.update_attributes(:observed_on_string => "")
      expect(@observation.observed_on).to be_blank
    end
  
    it "should set an iconic taxon if the taxon was set" do
      obs = Observation.make!
      expect(obs.iconic_taxon).to be_blank
      taxon = Taxon.make!(:iconic_taxon => Taxon.make!(:is_iconic => true))
      expect(taxon.iconic_taxon).not_to be_blank
      obs.taxon = taxon
      obs.save!
      expect(obs.iconic_taxon.name).to eq taxon.iconic_taxon.name
    end
  
    it "should remove an iconic taxon if the taxon was removed" do
      taxon = Taxon.make!(:iconic_taxon => Taxon.make!(:is_iconic => true))
      expect(taxon.iconic_taxon).not_to be_blank
      obs = Observation.make!(:taxon => taxon)
      expect(obs.iconic_taxon).not_to be_blank
      obs.taxon = nil
      obs.save!
      obs.reload
      expect(obs.iconic_taxon).to be_blank
    end

    it "should add a new taxon to the user's life list" do
      o = without_delay { Observation.make!(taxon: Taxon.make!) }
      expect( o.user.life_list.taxa ).to include o.taxon
      without_delay { o.update_attributes(taxon: Taxon.make!) }
      o.reload
      expect( o.user.life_list.taxa ).to include o.taxon
    end

    it "should remove an old taxon from the user's life list if that was the only obs" do
      o = without_delay { Observation.make!(taxon: Taxon.make!) }
      old_taxon = o.taxon
      expect( o.user.life_list.taxa ).to include o.taxon
      without_delay { o.update_attributes(taxon: Taxon.make!) }
      o.reload
      expect( o.user.life_list.taxa ).not_to include old_taxon
    end

    it "should not remove an old taxon from the user's life list if that was not the only obs" do
      o = without_delay { Observation.make!(taxon: Taxon.make!) }
      o1 = without_delay { Observation.make!(taxon: o.taxon, user: o.user) }
      old_taxon = o.taxon
      expect( o.user.life_list.taxa ).to include o.taxon
      without_delay { o.update_attributes(taxon: Taxon.make!) }
      o.reload
      expect( o.user.life_list.taxa ).to include old_taxon
    end

    it "should queue refresh jobs for associated project lists if the taxon changed" do
      o = Observation.make!(:taxon => Taxon.make!)
      pu = ProjectUser.make!(:user => o.user)
      po = ProjectObservation.make!(:observation => o, :project => pu.project)
      Delayed::Job.delete_all
      stamp = Time.now
      o.update_attributes(:taxon => Taxon.make!)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      # puts jobs.map(&:handler).inspect
      expect(jobs.select{|j| j.handler =~ /ProjectList.*refresh_with_observation/m}).not_to be_blank
    end
  
    it "should queue refresh job for check lists if the coordinates changed" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      o.update_attributes(:latitude => o.latitude + 1)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      # puts jobs.detect{|j| j.handler =~ /\:refresh_project_list\n/}.handler.inspect
      expect(jobs.select{|j| j.handler =~ /CheckList.*refresh_with_observation/m}).not_to be_blank
    end

    it "should only queue one job to refresh life lists if taxon changed" do
      o = Observation.make!(:taxon => Taxon.make!)
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update_attributes(:taxon => Taxon.make!)
      end
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /LifeList.*refresh_with_observation/m}.size).to eq(1)
    end

    it "should only queue one job to refresh project lists if taxon changed" do
      po = make_project_observation(:taxon => Taxon.make!)
      o = po.observation
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update_attributes(:taxon => Taxon.make!)
      end
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /ProjectList.*refresh_with_observation/m}.size).to eq(1)
    end

    it "should only queue one check list refresh job" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update_attributes(:latitude => o.latitude + 1)
      end
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      # puts jobs.detect{|j| j.handler =~ /\:refresh_project_list\n/}.handler.inspect
      expect(jobs.select{|j| j.handler =~ /CheckList.*refresh_with_observation/m}.size).to eq(1)
    end
  
    it "should queue refresh job for check lists if the taxon changed" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      o = Observation.find(o.id)
      o.update_attributes(:taxon => Taxon.make!)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      pattern = /CheckList.*refresh_with_observation/m
      job = jobs.detect{|j| j.handler =~ pattern}
      expect(job).not_to be_blank
      # puts job.handler.inspect
    end
  
    it "should queue refresh job for project lists if the taxon changed" do
      po = make_project_observation
      o = po.observation
      Delayed::Job.delete_all
      stamp = Time.now
      o.update_attributes(:taxon => Taxon.make!)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      pattern = /ProjectList.*refresh_with_observation/m
      job = jobs.detect{|j| j.handler =~ pattern}
      expect(job).not_to be_blank
      # puts job.handler.inspect
    end
  
    it "should not allow impossible coordinates" do
      o = Observation.make!
      o.update_attributes(:latitude => 100)
      expect(o).not_to be_valid
    
      o = Observation.make!
      o.update_attributes(:longitude => 200)
      expect(o).not_to be_valid
    
      o = Observation.make!
      o.update_attributes(:latitude => -100)
      expect(o).not_to be_valid
    
      o = Observation.make!
      o.update_attributes(:longitude => -200)
      expect(o).not_to be_valid
    end
  
    describe "quality_grade" do

      # some identification deletion callbacks need to happen after the transaction is complete
      before(:all) { DatabaseCleaner.strategy = :truncation }
      after(:all)  { DatabaseCleaner.strategy = :transaction }
    
      it "should become research when it qualifies" do
        o = Observation.make!(:taxon => Taxon.make!(rank: 'species'), latitude: 1, longitude: 1)
        i = Identification.make!(:observation => o, :taxon => o.taxon)
        o.photos << LocalPhoto.make!(:user => o.user)
        o.reload
        expect(o.quality_grade).to eq Observation::CASUAL
        o.update_attributes(:observed_on_string => "yesterday")
        o.reload
        expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
      end

      it "should be research grade if community taxon at family or lower" do
        o = make_research_grade_candidate_observation(taxon: Taxon.make!(rank: 'species'))
        Identification.make!(observation: o, taxon: o.taxon)
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end
      it "should not be research grade if community taxon above family" do
        o = make_research_grade_candidate_observation(taxon: Taxon.make!(rank: 'order'))
        Identification.make!(observation: o, taxon: o.taxon)
        o.reload
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end
    
      it "should become needs ID when taxon changes" do
        o = make_research_grade_observation
        expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
        new_taxon = Taxon.make!
        o = Observation.find(o.id)
        o.update_attributes(:taxon => new_taxon)
        expect(o.quality_grade).to eq Observation::NEEDS_ID
      end
    
      it "should become casual when date removed" do
        o = make_research_grade_observation
        expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
        o.update_attributes(:observed_on_string => "")
        expect(o.quality_grade).to eq Observation::CASUAL
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
        expect(o.community_taxon).to eq child
        expect(o.taxon).to eq child
        expect(o).to be_community_supported_id
        expect(o).to be_research_grade
      end

      it "should be needs ID if no identifications" do
        o = make_research_grade_observation
        o.identifications.destroy_all
        o.reload
        expect(o.quality_grade).to eq Observation::NEEDS_ID
      end

      it "should not be research if the community taxon is Life" do
        load_test_taxa
        o = make_research_grade_observation
        o.identifications.destroy_all
        i1 = Identification.make!(:observation => o, :taxon => @Animalia)
        i2 = Identification.make!(:observation => o, :taxon => @Plantae)
        o.reload
        expect(o.community_taxon).to eq @Life
        expect(o.quality_grade).to eq Observation::NEEDS_ID
      end

      it "should be casual if the community taxon is Homo sapiens" do
        t = Taxon.make!( name: "Homo sapiens", rank: Taxon::SPECIES )
        o = make_research_grade_observation( taxon: t )
        expect( o.community_taxon ).to eq t
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual if flagged" do
        o = make_research_grade_observation
        Flag.make!(:flaggable => o, :flag => Flag::SPAM)
        o.reload
        expect( o ).not_to be_appropriate
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual if photos flagged" do
        o = make_research_grade_observation
        Flag.make!(:flaggable => o.photos.first, :flag => Flag::COPYRIGHT_INFRINGEMENT)
        o.reload
        expect(o.quality_grade).to eq Observation::CASUAL
      end

      # needs ID
      it "should be research grade if community ID at species or lower and research grade candidate" do
        o = make_research_grade_candidate_observation
        t = Taxon.make!(rank: Taxon::SPECIES)
        2.times { Identification.make!(observation: o, taxon: t)}
        expect( o.community_taxon.rank ).to eq Taxon::SPECIES
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be casual if community ID at species or lower and not research grade candidate" do
        o = Observation.make!
        t = Taxon.make!(rank: Taxon::SPECIES)
        2.times { Identification.make!(observation: o, taxon: t)}
        expect( o.community_taxon.rank ).to eq Taxon::SPECIES
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be needs ID if elligible" do
        o = make_research_grade_candidate_observation
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      it "should be casual if voted out" do
        o = Observation.make!
        o.downvote_from User.make!, vote_scope: 'needs_id'
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should not notify the observer if voted out" do
        # ,queue_if: lambda { |record| record.vote_scope.blank? }
        o = Observation.make!
        without_delay do
          expect {
            o.downvote_from User.make!, vote_scope: 'needs_id'
          }.not_to change(UpdateAction, :count)
        end
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual by default" do
        o = Observation.make!
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual if verifiable but voted out and community taxon above family" do
        o = make_research_grade_candidate_observation(taxon: Taxon.make!(rank: Taxon::ORDER))
        Identification.make!(observation: o, taxon: o.taxon)
        o.reload
        expect( o.community_taxon.rank ).to eq Taxon::ORDER
        o.downvote_from User.make!, vote_scope: 'needs_id'
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be research grade if verifiable but voted out and community taxon below family" do
        o = make_research_grade_candidate_observation
        t = Taxon.make!(rank: Taxon::GENUS)
        2.times do
          Identification.make!(taxon: t, observation: o)
        end
        o.reload
        expect( o.community_taxon ).to eq t
        o.downvote_from User.make!, vote_scope: 'needs_id'
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be research grade if verifiable but voted out and community taxon below family but above genus" do
        o = make_research_grade_candidate_observation
        t = Taxon.make!(rank: Taxon::SUBFAMILY)
        2.times do
          Identification.make!(taxon: t, observation: o)
        end
        o.reload
        expect( o.community_taxon ).to eq t
        o.downvote_from User.make!, vote_scope: 'needs_id'
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be needs ID if verifiable and voted back in" do
        o = make_research_grade_candidate_observation
        o.downvote_from User.make!, vote_scope: 'needs_id'
        o.upvote_from User.make!, vote_scope: 'needs_id'
        o.reload
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      describe "with id_please" do
        it "should be needs_id if user checked id_please on update" do
          o = make_research_grade_observation
          expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
          o.update_attributes(id_please: true)
          o.reload
          expect( o.quality_grade ).to eq Observation::NEEDS_ID
        end
        
        it "should add vote for needs_id if user checks id_please on update" do
          o = make_research_grade_observation
          expect( o.get_upvotes(vote_scope: 'needs_id').size ).to eq 0
          o.update_attributes(id_please: true)
          o.reload
          expect( o.get_upvotes(vote_scope: 'needs_id').size ).to eq 1
        end

        it "should not add vote for needs_id if user checks id_please on create" do
          o = make_research_grade_observation(id_please: true)
          expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
          expect( o.get_upvotes(vote_scope: 'needs_id').size ).to eq 0
        end
      end

      it "should work with query" do
        o_needs_id = make_research_grade_candidate_observation
        o_needs_id.reload
        o_verified = make_research_grade_observation
        o_casual = Observation.make!
        expect( Observation.query(quality_grade: Observation::NEEDS_ID) ).to include o_needs_id
        expect( Observation.query(quality_grade: Observation::NEEDS_ID) ).not_to include o_verified
        expect( Observation.query(quality_grade: Observation::NEEDS_ID) ).not_to include o_casual
        expect( Observation.query(quality_grade: Observation::RESEARCH_GRADE) ).to include o_verified
        expect( Observation.query(quality_grade: Observation::CASUAL) ).to include o_casual
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
        expect(o).not_to be_coordinates_obscured
        o.update_attributes(:taxon => t)
        expect(o).to be_coordinates_obscured
      end

      it "should not obscure coordinates if taxon has a conservation status in another place" do
        p = make_place_with_geom
        t = Taxon.make!(:rank => Taxon::SPECIES)
        cs = ConservationStatus.make!(:place => p, :taxon => t)
        o = Observation.make!(:latitude => -1*p.latitude, :longitude => p.longitude)
        expect(o).not_to be_coordinates_obscured
        o.update_attributes(:taxon => t)
        expect(o).not_to be_coordinates_obscured
      end

      it "should obscure coordinates if locally threatened but globally secure" do
        p = make_place_with_geom
        t = Taxon.make!(:rank => Taxon::SPECIES)
        local_cs = ConservationStatus.make!(:place => p, :taxon => t)
        global_cs = ConservationStatus.make!(:taxon => t, :status => "LC", :iucn => Taxon::IUCN_LEAST_CONCERN, :geoprivacy => "open")
        o = Observation.make!(:latitude => p.latitude, :longitude => p.longitude)
        expect(o).not_to be_coordinates_obscured
        o.update_attributes(:taxon => t)
        expect(o).to be_coordinates_obscured
      end

      it "should not obscure coordinates if conservation statuses exist but all are open" do
        p = make_place_with_geom
        t = Taxon.make!(:rank => Taxon::SPECIES)
        cs = ConservationStatus.make!(:place => p, :taxon => t, :geoprivacy => Observation::OPEN)
        cs_global = ConservationStatus.make!(:taxon => t, :geoprivacy => Observation::OPEN)
        o = Observation.make!(:latitude => -1*p.latitude, :longitude => p.longitude)
        expect(o).not_to be_coordinates_obscured
        o.update_attributes(:taxon => t)
        expect(o).not_to be_coordinates_obscured
      end

      describe "when at least one ID is of a threatened taxon" do
        let(:place) { make_place_with_geom }
        let(:o) { make_research_grade_observation( latitude: place.latitude, longitude: place.longitude ) }
        let(:threatened_taxon) { Taxon.make!( rank: Taxon::SPECIES ) }
        it "should obscure coordinates if taxon has a conservation status in the place observed" do
          expect( o ).not_to be_coordinates_obscured
          ConservationStatus.make!( place: place, taxon: threatened_taxon )
          Identification.make!( observation: o, taxon: threatened_taxon )
          o.reload
          expect( o ).to be_coordinates_obscured
        end
        it "should not obscure coordinates if taxon has a conservation status in another place" do
          o.update_attributes( latitude: ( place.latitude * -1 ), longitude: ( place.longitude * -1 ) )
          expect( o ).not_to be_coordinates_obscured
          ConservationStatus.make!( place: place, taxon: threatened_taxon )
          Identification.make!( observation: o, taxon: threatened_taxon )
          o.reload
          expect( o ).not_to be_coordinates_obscured
        end
        it "should obscure coordinates if locally threatened but globally secure" do
          expect( o ).not_to be_coordinates_obscured
          global_cs = ConservationStatus.make!( taxon: threatened_taxon )
          local_cs = ConservationStatus.make!( place: place, taxon: threatened_taxon )
          Identification.make!( observation: o, taxon: threatened_taxon )
          o.reload
          expect( o ).to be_coordinates_obscured
        end
        it "should not obscure coordinates if conservation statuses exist but all are open" do
          expect( o ).not_to be_coordinates_obscured
          global_cs = ConservationStatus.make!( taxon: threatened_taxon, geoprivacy: Observation::OPEN )
          local_cs = ConservationStatus.make!( place: place, taxon: threatened_taxon, geoprivacy: Observation::OPEN )
          Identification.make!( observation: o, taxon: threatened_taxon )
          o.reload
          expect( o ).not_to be_coordinates_obscured
        end
      end

      describe "when a dissenting ID is of a non-threatened taxon" do
        before { load_test_taxa }
        let(:cs) { ConservationStatus.make!( taxon: @Calypte_anna ) }
        let(:o) { Observation.make!( taxon: cs.taxon, latitude: 1, longitude: 1 ) }
        before do
          expect( o.community_taxon ).to be_blank
          Identification.make!( observation: o, taxon: o.taxon )
          o.reload
          expect( o.community_taxon ).to eq cs.taxon
          expect( o ).to be_coordinates_obscured
        end
        it "should not reveal the coordinates" do
          i2 = Identification.make!( observation: o, taxon: @Pseudacris_regilla )
          o.reload
          expect( o.community_taxon ).not_to eq cs.taxon
          expect( o ).to be_coordinates_obscured
        end
        it "should reveal the coordinates if the dissenting ID is not current" do
          i2 = Identification.make!( observation: o, taxon: @Pseudacris_regilla )
          i3 = Identification.make!( observation: o, taxon: @Calypte_anna, user: i2.user )
          i2.reload
          i3.reload
          expect( i2 ).not_to be_current
          expect( i3 ).to be_current
          o.reload
          expect( o.community_taxon ).to eq cs.taxon
          expect( o ).to be_coordinates_obscured
        end
      end
    end

    it "should increment the taxon's counter cache" do
      o = Observation.make!
      t = Taxon.make!
      expect(t.observations_count).to eq(0)
      o.update_attributes(:taxon => t)
      Delayed::Worker.new.work_off
      t.reload
      expect(t.observations_count).to eq(1)
    end
  
    it "should increment the taxon's ancestors' counter caches" do
      o = Observation.make!
      p = without_delay { Taxon.make! }
      t = without_delay { Taxon.make!(:parent => p) }
      expect(p.observations_count).to eq 0
      o.update_attributes(:taxon => t)
      Delayed::Worker.new.work_off
      p.reload
      expect(p.observations_count).to eq 1
      Observation.elastic_index!(ids: [ o.id ], delay: true)
      p.reload
      expect(p.observations_count).to eq 1
    end

    it "should decrement the taxon's counter cache" do
      t = Taxon.make!
      o = without_delay {Observation.make!(:taxon => t)}
      t.reload
      expect(t.observations_count).to eq(1)
      o = without_delay {o.update_attributes(:taxon => nil)}
      t.reload
      expect(t.observations_count).to eq(0)
    end
  
    it "should decrement the taxon's ancestors' counter caches" do
      p = Taxon.make!
      t = Taxon.make!(:parent => p)
      o = without_delay {Observation.make!(:taxon => t)}
      p.reload
      expect(p.observations_count).to eq(1)
      o = without_delay {o.update_attributes(:taxon => nil)}
      p.reload
      expect(p.observations_count).to eq(0)
    end

    it "should update a life listed taxon stats" do
      t = Taxon.make!
      u = User.make!
      without_delay do
        l = LifeList.make!(user: u)
        l.add_taxon(t)
      end
      o1 = without_delay { Observation.make!(taxon: t, user: u, observed_on_string: '2014-03-01') }
      o2 = without_delay { Observation.make!(taxon: t, user: u, observed_on_string: '2015-03-01') }
      lt = o1.user.life_list.listed_taxa.where(taxon_id: t.id).first
      expect(lt.first_observation).to eq o1
      expect(lt.last_observation).to eq o2
    end
  end

  describe "destruction" do
    before(:each) { enable_elastic_indexing(UpdateAction) }
    after(:each) { disable_elastic_indexing(UpdateAction) }

    it "should decrement the counter cache in users" do
      @observation = Observation.make!
      user = @observation.user
      user.reload
      old_count = user.observations_count
      @observation.destroy
      user.reload
      expect(user.observations_count).to eq old_count - 1
    end
  
    it "should queue a DJ job to refresh lists" do
      Delayed::Job.delete_all
      stamp = Time.now
      Observation.make!(:taxon => Taxon.make!)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /List.*refresh_with_observation/m}).not_to be_blank
    end

    it "should delete associated updates" do
      subscriber = User.make!
      user = User.make!
      s = Subscription.make!(:user => subscriber, :resource => user)
      o = Observation.make(:user => user)
      without_delay { o.save! }
      update = UpdateSubscriber.where(:subscriber_id => subscriber).last
      expect(update).not_to be_blank
      o.destroy
      expect(UpdateSubscriber.find_by_id(update.id)).to be_blank
    end

    it "should delete associated project observations" do
      po = make_project_observation
      o = po.observation
      o.destroy
      expect(ProjectObservation.find_by_id(po.id)).to be_blank
    end

    it "should decrement the taxon's counter cache" do
      t = Taxon.make!
      o = without_delay{Observation.make!(:taxon => t)}
      t.reload
      expect(t.observations_count).to eq(1)
      o.destroy
      Delayed::Worker.new.work_off
      t.reload
      expect(t.observations_count).to eq(0)
    end
  
    it "should decrement the taxon's ancestors' counter caches" do
      p = Taxon.make!
      t = Taxon.make!(:parent => p)
      o = without_delay {Observation.make!(:taxon => t)}
      p.reload
      expect(p.observations_count).to eq(1)
      o.destroy
      Delayed::Worker.new.work_off
      p.reload
      expect(p.observations_count).to eq(0)
    end

    it "should create a deleted observation" do
      o = Observation.make!
      o.destroy
      deleted_obs = DeletedObservation.where(:observation_id => o.id).first
      expect(deleted_obs).not_to be_blank
      expect(deleted_obs.user_id).to eq o.user_id
    end
  end

  describe "species_guess parsing" do
    before(:each) do
      @observation = Observation.make!
    end
  
    it "should choose a taxon if the guess corresponds to a unique taxon" do
      taxon = Taxon.make!
      @observation.taxon = nil
      @observation.species_guess = taxon.name
      @observation.save
      expect(@observation.taxon_id).to eq taxon.id
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
      expect(@observation.taxon_id).to eq taxon.id
    end

    it "should not choose a taxon from species_guess if exact matches don't form a subtree" do
      taxon = Taxon.make!(:rank => "species", :parent => Taxon.make!, :name => "Spirolobicus bananaensis")
      child = Taxon.make!(:rank => "subspecies", :parent => taxon, :name => "#{taxon.name} foo")
      taxon2 = Taxon.make!(:rank => "species", :parent => Taxon.make!)
      common_name = "Spiraled Banana Shrew"
      TaxonName.make!(:taxon => taxon, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      TaxonName.make!(:taxon => child, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      TaxonName.make!(:taxon => taxon2, :name => common_name, :lexicon => TaxonName::LEXICONS[:ENGLISH])
      expect(child.ancestors).to include(taxon)
      expect(child.ancestors).not_to include(taxon2)
      expect(Taxon.joins(:taxon_names).where("taxon_names.name = ?", common_name).count).to eq(3)
      @observation.taxon = nil
      @observation.species_guess = common_name
      @observation.save
      expect(@observation.taxon_id).to be_blank
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
      expect(@observation.taxon_id).to eq taxon.id
    end
  
    it "should not make a guess for problematic names" do
      Taxon::PROBLEM_NAMES.each do |name|
        t = Taxon.make!(:name => name.capitalize)
        o = Observation.make!(:species_guess => name)
        expect(o.taxon_id).not_to eq t.id
      end
    end
  
    it "should choose a taxon from a parenthesized scientific name" do
      name = "Northern Pygmy Owl (Glaucidium gnoma)"
      t = Taxon.make!(:name => "Glaucidium gnoma")
      o = Observation.make!(:species_guess => name)
      expect(o.taxon_id).to eq t.id
    end
  
    it "should choose a taxon from blah sp" do
      name = "Clarkia sp"
      t = Taxon.make!(:name => "Clarkia")
      o = Observation.make!(:species_guess => name)
      expect(o.taxon_id).to eq t.id
    
      name = "Clarkia sp."
      o = Observation.make!(:species_guess => name)
      expect(o.taxon_id).to eq t.id
    end
  
    it "should choose a taxon from blah ssp" do
      name = "Clarkia ssp"
      t = Taxon.make!(:name => "Clarkia")
      o = Observation.make!(:species_guess => name)
      expect(o.taxon_id).to eq t.id
    
      name = "Clarkia ssp."
      o = Observation.make!(:species_guess => name)
      expect(o.taxon_id).to eq t.id
    end

    it "should not make a guess if ends in a question mark" do
      t = Taxon.make!(:name => "Foo bar")
      o = Observation.make!(:species_guess => "#{t.name}?")
      expect(o.taxon).to be_blank
    end
  end

  describe "named scopes" do
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
      expect(obs).to include(@pos)
      expect(obs).not_to include(@neg)
    end

    it "should find observations in a bounding box in a year" do
      pos = Observation.make!(:latitude => @pos.latitude, :longitude => @pos.longitude, :observed_on_string => "2010-01-01")
      neg = Observation.make!(:latitude => @pos.latitude, :longitude => @pos.longitude, :observed_on_string => "2011-01-01")
      observations = Observation.in_bounding_box(20,20,30,30).on("2010")
      expect(observations.map(&:id)).to include(pos.id)
      expect(observations.map(&:id)).not_to include(neg.id)
    end

    it "should find observations in a bounding box spanning the date line" do
      pos = Observation.make!(:latitude => 0, :longitude => 179)
      neg = Observation.make!(:latitude => 0, :longitude => 170)
      observations = Observation.in_bounding_box(-1,178,1,-178)
      expect(observations.map(&:id)).to include(pos.id)
      expect(observations.map(&:id)).not_to include(neg.id)
    end
  
    it "should find observations using the shorter box method" do
      obs = Observation.near_point(20, 20).all
      expect(obs).to include(@pos)
      expect(obs).not_to include(@neg)
    end
  
    it "should find observations with latitude and longitude" do
      obs = Observation.has_geo()
      expect(obs).to include(@pos, @neg)
      expect(obs).not_to include(@between)
    end
  
    it "should find observations requesting identification" do 
      obs = Observation.has_id_please
      expect(obs).to include(@pos)
      expect(obs).not_to include(@neg)
    end
  
    it "should find observations with photos" do
      ObservationPhoto.make!(:observation => @pos)
      obs = Observation.has_photos.all
      expect(obs).to include(@pos)
      expect(obs).not_to include(@neg)
    end
  
    it "should find observations observed after a certain time" do
      @after_formats.each do |format|
        obs = Observation.observed_after(format)
        expect(obs).to include(@neg, @between)
        expect(obs).not_to include(@pos)
      end
    end
  
    it "should find observations observed before a specific time" do
      @before_formats.each do |format|
        obs = Observation.observed_before(format)
        expect(obs).to include(@pos, @between)
        expect(obs).not_to include(@neg)
      end
    end
  
    it "should find observations observed between two time bounds" do
      @after_formats.each do |after_format|
        @before_formats.each do |before_format|
          obs = Observation.observed_after(after_format).observed_before(before_format)
          expect(obs).to include(@between)
          expect(obs).not_to include(@pos, @neg)
        end
      end
    end
  
    it "should find observations created after a certain time" do
      @after_formats.each do |format|
        obs = Observation.created_after(format)
        expect(obs).to include(@neg, @between)
        expect(obs).not_to include(@pos)
      end
    end
  
    it "should find observations created before a specific time" do
      @before_formats.each do |format|
        obs = Observation.created_before(format)
        expect(obs).to include(@pos, @between)
        expect(obs).not_to include(@neg)
      end
    end

    it "should find observations created between two time bounds" do
      @after_formats.each do |after_format|
        @before_formats.each do |before_format|
          obs = Observation.created_after(after_format).created_before(before_format)
          expect(obs).to include(@between)
          expect(obs).not_to include(@pos, @neg)
        end
      end
    end
 
    it "should find observations updated after a certain time" do
      @after_formats.each do |format|
        obs = Observation.updated_after(format)
        expect(obs).to include(@neg, @between)
        expect(obs).not_to include(@pos)
      end
    end
  
    it "should find observations updated before a specific time" do
      @before_formats.each do |format|
        obs = Observation.updated_before(format)
        expect(obs).to include(@pos, @between)
        expect(obs).not_to include(@neg)
      end
    end
  
    it "should find observations updated between two time bounds" do
      @after_formats.each do |after_format|
        @before_formats.each do |before_format|
          obs = Observation.updated_after(after_format).updated_before(before_format)
          expect(obs).to include(@between)
          expect(obs).not_to include(@pos, @neg)
        end
      end
    end
  
    it "should find observations in one iconic taxon" do
      observations = Observation.has_iconic_taxa(@mollusca)
      expect(observations).to include(@aaron_saw_a_mollusk)
      expect(observations.map(&:id)).not_to include(@aaron_saw_an_amphibian.id)
    end
  
    it "should find observations in many iconic taxa" do
      observations = Observation.has_iconic_taxa(
        [@mollusca, @amphibia])
      expect(observations).to include(@aaron_saw_a_mollusk)
      expect(observations).to include(@aaron_saw_an_amphibian)
    end
  
    it "should find observations with NO iconic taxon" do
      observations = Observation.has_iconic_taxa(
        [@mollusca, nil])
      expect(observations).to include(@aaron_saw_a_mollusk)
      expect(observations).to include(@aaron_saw_a_mystery)
    end
  
    it "should order observations by created_at" do
      last_obs = Observation.make!
      expect(Observation.order_by('created_at').to_a.last).to eq last_obs
    end
  
    it "should reverse order observations by created_at" do
      last_obs = Observation.make!
      expect(Observation.order_by('created_at DESC').first).to eq last_obs
    end
  
    it "should not find anything for a non-existant taxon ID" do
      expect(Observation.of(91919191)).to be_empty
    end

    it "should not bail on invalid dates" do
      expect {
        o = Observation.on("2013-02-30").all
      }.not_to raise_error
    end

    it "scopes by reviewed_by" do
      o = Observation.make!
      u = User.make!
      ObservationReview.make!(observation: o, user: u)
      expect( Observation.reviewed_by(u).first ).to eq o
    end

    it "scopes by not_reviewed_by" do
      o = Observation.make!
      u = User.make!
      expect( Observation.not_reviewed_by(u).count ).to eq Observation.count
    end

    describe :in_projects do
      it "should find observations in a project by id" do
        po = make_project_observation
        other_o = Observation.make!
        expect( Observation.in_projects(po.project_id) ).to include po.observation
        expect( Observation.in_projects(po.project_id) ).not_to include other_o
      end
      it "should find observations in a project by slug" do
        po = make_project_observation
        other_o = Observation.make!
        expect( Observation.in_projects(po.project.slug) ).to include po.observation
        expect( Observation.in_projects(po.project.slug) ).not_to include other_o
      end
      it "should find observations in a project that begins with a number" do
        other_p = Project.make!
        po = make_project_observation(project: Project.make!(title: "#{other_p.id}MBC: Five Minute Bird Counts New Zealand"))
        expect( po.project.slug.to_i ).to eq other_p.id
        other_o = Observation.make!
        expect( Observation.in_projects(po.project_id) ).to include po.observation
        expect( Observation.in_projects(po.project_id) ).not_to include other_o
      end
      it "should find observations in a project that begins with a number by slug" do
        other_p = Project.make!
        po = make_project_observation(project: Project.make!(title: "#{other_p.id}MBC: Five Minute Bird Counts New Zealand"))
        expect( po.project.slug.to_i ).to eq other_p.id
        other_o = Observation.make!
        expect( Observation.in_projects(po.project.slug) ).to include po.observation
        expect( Observation.in_projects(po.project.slug) ).not_to include other_o
      end
    end

    describe :of do
      it "should find observations of a taxon" do
        t = without_delay { Taxon.make! }
        o = Observation.make!(:taxon => t)
        expect(Observation.of(t).first).to eq o
      end
      it "should find observations of a descendant of a taxon" do
        t = without_delay { Taxon.make! }
        c = without_delay { Taxon.make!(:parent => t) }
        o = Observation.make!(:taxon => c)
        expect(Observation.of(t).first).to eq o
      end
    end

    describe :with_identifications_of do
      it "should include observations with identifications of the taxon" do
        i = Identification.make!
        o = Observation.make!
        AncestryDenormalizer.denormalize
        expect( Observation.with_identifications_of( i.taxon ) ).to include i.observation
        expect( Observation.with_identifications_of( i.taxon ) ).not_to include o
      end
      it "should include observations with identifications of descendant taxa" do
        parent = Taxon.make!( rank: Taxon::GENUS )
        child = Taxon.make!( rank: Taxon::SPECIES, parent: parent )
        i = Identification.make!( taxon: child )
        AncestryDenormalizer.denormalize
        expect( Observation.with_identifications_of( parent ) ).to include i.observation
      end
      it "should not return duplicate observations when there are multiple identifications" do
        o = Observation.make!
        i1 = Identification.make!( observation: o )
        i2 = Identification.make!( observation: o, taxon: i1.taxon )
        AncestryDenormalizer.denormalize
        expect( Observation.with_identifications_of( i1.taxon ).count ).to eq 1
      end
    end
  end

  describe "private location data" do
    let(:original_place_guess) { "place of unquenchable secrecy" }
    let(:original_latitude) { 38.1234 }
    let(:original_longitude) { -122.1234 }
    let(:cs) { ConservationStatus.make! }
    let(:defaults) { {
      taxon: cs.taxon,
      latitude: original_latitude,
      longitude: original_longitude,
      place_guess: original_place_guess
    } }
  
    it "should be set automatically if the taxon is threatened" do
      observation = Observation.make!( defaults )
      expect( observation.taxon ).to be_threatened
      expect( observation.private_longitude ).not_to be_blank
      expect( observation.private_longitude ).not_to eq observation.longitude
      expect( observation.place_guess ).to eq Observation.place_guess_from_latlon(
        observation.latitude, observation.longitude, acc: observation.public_positional_accuracy )
      expect( observation.private_place_guess ).to eq original_place_guess
    end
  
    it "should be set automatically if the taxon's parent is threatened" do
      child = Taxon.make!( parent: cs.taxon, rank: "subspecies" )
      observation = Observation.make!( defaults.merge( taxon: child ) )
      expect( observation.taxon ).not_to be_threatened
      expect( observation.private_longitude ).not_to be_blank
      expect( observation.private_longitude ).not_to eq observation.longitude
      expect( observation.place_guess ).to eq Observation.place_guess_from_latlon(
        observation.latitude, observation.longitude, acc: observation.public_positional_accuracy )
      expect( observation.private_place_guess ).to eq original_place_guess
    end
  
    it "should be unset if the taxon changes to something unthreatened" do
      observation = Observation.make!( defaults )
      observation.update_attributes( taxon: Taxon.make! )
      observation.reload
      expect( observation.taxon ).not_to be_threatened
      expect( observation.owners_identification.taxon ).not_to be_threatened
      expect( observation.identifications.current.size ).to eq 1
      expect( observation.private_longitude ).to be_blank
      expect( observation.place_guess ).to eq original_place_guess
      expect( observation.private_place_guess ).to be_blank
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
        observation = Observation.make!( place_guess: place_guess )
        expect( observation.latitude ).not_to be_blank
        observation.update_attributes( taxon: cs.taxon )
        expect( observation.place_guess.to_s ).to eq ""
      end
    end
  
    it "should not be included in json" do
      observation = Observation.make!( defaults )
      expect( observation.to_json ).not_to match( /private_latitude/ )
      expect( observation.to_json ).not_to match( /#{observation.private_latitude}/ )
      expect( observation.to_json ).not_to match( /#{observation.private_place_guess}/ )
    end
  
    it "should not be included in a json array" do
      observation = Observation.make!( defaults )
      Observation.make!
      observations = Observation.paginate( page: 1, per_page: 2).order( id: :desc )
      expect( observations.to_json ).not_to match( /private_latitude/ )
      expect( observations.to_json ).not_to match( /#{observation.private_latitude}/ )
      expect( observation.to_json ).not_to match( /#{observation.private_place_guess}/ )
    end

    it "should not be included in by_login_all csv generated for others" do
      observation = Observation.make!( defaults )
      Observation.make!
      path = Observation.generate_csv_for( observation.user )
      txt = open( path ).read
      expect( txt ).not_to match( /private_latitude/ )
      expect( txt ).not_to match( /#{observation.private_latitude}/ )
      expect( observation.to_json ).not_to match( /#{observation.private_place_guess}/ )
    end

    it "should be visible to curators of projects to which the observation has been added" do
      po = make_project_observation
      expect( po.project_user.preferred_curator_coordinate_access ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER
      expect( po ).to be_prefers_curator_coordinate_access
      o = po.observation
      o.update_attributes( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1 )
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::CURATOR )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be true
    end

    it "should be visible to managers of projects to which the observation has been added" do
      po = make_project_observation
      o = po.observation
      o.update_attributes( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1 )
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::MANAGER )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be true
    end

    it "should not be visible to managers of projects to which the observation has been added if the observer is not a member" do
      po = ProjectObservation.make!
      expect( po.observation.user.project_ids ).not_to include po.project_id
      o = po.observation
      o.update_attributes( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1 )
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::MANAGER )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be false
    end

    it "should be visible to managers of projects if observer prefers it" do
      po = ProjectObservation.make!( prefers_curator_coordinate_access: true )
      expect( po.observation.user.project_ids ).not_to include po.project_id
      o = po.observation
      o.update_attributes( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1)
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::MANAGER )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be true
    end

    it "should not remove private_place_guess when an identificaiton gets added" do
      original_place_guess = "the secret place"
      o = Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE, place_guess: original_place_guess )
      expect( o.private_place_guess ).to eq original_place_guess
      i = Identification.make!( observation: o )
      o.reload
      expect( o.private_place_guess ).to eq original_place_guess
    end
  end
  
  describe "obscure_coordinates" do
    it "should not affect observations without coordinates" do
      o = Observation.make!
      expect(o.latitude).to be_blank
      o.obscure_coordinates
      expect(o.latitude).to be_blank
      expect(o.private_latitude).to be_blank
      expect(o.longitude).to be_blank
      expect(o.private_longitude).to be_blank
    end
  
    it "should not affect already obscured coordinates" do
      o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::OBSCURED)
      lat = o.latitude
      private_lat = o.private_latitude
      expect(o).to be_coordinates_obscured
      o.obscure_coordinates
      o.reload
      expect(o.latitude.to_f).to eq lat.to_f
      expect(o.private_latitude.to_f).to eq private_lat.to_f
    end
  
    it "should not affect already coordinates of a protected taxon" do
      o = make_observation_of_threatened
      lat = o.latitude
      private_lat = o.private_latitude
      expect(o).to be_coordinates_obscured
      o.update_attributes(:geoprivacy => Observation::OBSCURED)
      o.reload
      expect(o.latitude.to_f).to eq lat.to_f
      expect(o.private_latitude.to_f).to eq private_lat.to_f
    end
  
  end

  describe "unobscure_coordinates" do
    it "should work" do
      taxon = make_threatened_taxon
      true_lat = 38.0
      true_lon = -122.0
      o = Observation.make!(:taxon => taxon, :latitude => true_lat, :longitude => true_lon)
      expect(o).to be_coordinates_obscured
      expect(o.latitude.to_f).not_to eq true_lat
      expect(o.longitude.to_f).not_to eq true_lon
      o.unobscure_coordinates
      expect(o).not_to be_coordinates_obscured
      expect(o.latitude.to_f).to eq true_lat
      expect(o.longitude.to_f).to eq true_lon
    end
  
    it "should not affect observations without coordinates" do
      o = Observation.make!
      expect(o.latitude).to be_blank
      o.unobscure_coordinates
      expect(o.latitude).to be_blank
      expect(o.private_latitude).to be_blank
      expect(o.longitude).to be_blank
      expect(o.private_longitude).to be_blank
    end
  
    it "should not obscure observations with obscured geoprivacy" do
      taxon = make_threatened_taxon
      o = Observation.make!(:latitude => 38, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      o.unobscure_coordinates
      expect(o).to be_coordinates_obscured
    end
  
    it "should not obscure observations with private geoprivacy" do
      taxon = make_threatened_taxon
      o = Observation.make!(:latitude => 38, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.unobscure_coordinates
      expect(o).to be_coordinates_obscured
      expect(o.latitude).to be_blank
    end

  end

  describe "geoprivacy" do
    it "should obscure coordinates when private" do
      o = Observation.make!(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      expect(o).to be_coordinates_obscured
    end
  
    it "should remove public coordinates when private" do
      o = Observation.make!(latitude: 37, longitude: -122, geoprivacy: Observation::PRIVATE)
      expect(o.latitude).to be_blank
      expect(o.longitude).to be_blank
    end

    it "should remove place_guess when private" do
      o = Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE, place_guess: "foo" )
      expect( o.place_guess ).to be_blank
    end

    it "should remove public coordinates when moving from obscured to private" do
      o = Observation.make!(latitude: 37, longitude: -122, geoprivacy: Observation::OBSCURED)
      expect(o.latitude).not_to be_blank
      expect(o.longitude).not_to be_blank
      o.update_attributes(geoprivacy: Observation::PRIVATE)
      expect(o.latitude).to be_blank
      expect(o.longitude).to be_blank
    end
  
    it "should remove public coordinates when private if coords change but not geoprivacy" do
      o = Observation.make!(:latitude => 37, :longitude => -122, :geoprivacy => Observation::PRIVATE)
      o.update_attributes(:latitude => 1, :longitude => 1)
      expect(o).to be_coordinates_obscured
      expect(o.latitude).to be_blank
      expect(o.longitude).to be_blank
    end
  
    it "should obscure coordinates when obscured" do
      o = Observation.make!(:latitude => 37, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      expect(o).to be_coordinates_obscured
    end
  
    it "should not unobscure observations of threatened taxa" do
      taxon = make_threatened_taxon
      o = Observation.make!(:taxon => taxon, :latitude => 37, :longitude => -122, :geoprivacy => Observation::OBSCURED)
      expect(o).to be_coordinates_obscured
      o.update_attributes(:geoprivacy => nil)
      expect(o.geoprivacy).to be_blank
      expect(o).to be_coordinates_obscured
    end
  
    it "should remove public coordinates when private even if taxon threatened" do
      taxon = make_threatened_taxon
      o = Observation.make!(:latitude => 37, :longitude => -122, :taxon => taxon)
      expect(o).to be_coordinates_obscured
      expect(o.latitude).not_to be_blank
      o.update_attributes(:geoprivacy => Observation::PRIVATE)
      expect(o.latitude).to be_blank
      expect(o.longitude).to be_blank
    end
  
    it "should restore public coordinates when removing geoprivacy" do
      lat, lon = [37, -122]
      o = Observation.make!(:latitude => lat, :longitude => lon, :geoprivacy => Observation::PRIVATE)
      expect(o.latitude).to be_blank
      expect(o.longitude).to be_blank
      o.update_attributes(:geoprivacy => nil)
      expect(o.latitude.to_f).to eq lat
      expect(o.longitude.to_f).to eq lon
    end

    it "should be nil if not obscured or private" do
      o = Observation.make!(:geoprivacy => "open")
      expect(o.geoprivacy).to be_nil
    end

    it "should remove place_guess from to_plain_s" do
      original_place_guess = "Duluth, MN"
      o = Observation.make!( place_guess: original_place_guess, latitude: 1, longitude: 1 )
      expect( o.to_plain_s ).to be =~ /#{original_place_guess}/
      o.update_attributes( geoprivacy: Observation::OBSCURED )
      expect( o.to_plain_s ).not_to be =~ /#{original_place_guess}/
      expect( o.private_place_guess ).not_to be_blank
    end
  end

  describe "geom" do
    it "should be set with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      expect(o.geom).not_to be_blank
    end
  
    it "should not be set without coords" do
      o = Observation.make!
      expect(o.geom).to be_blank
    end
  
    it "should change with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      expect(o.geom.y).to eq 1.0
      o.update_attributes(:latitude => 2)
      expect(o.geom.y).to eq 2.0
    end
  
    it "should go away with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.update_attributes(:latitude => nil, :longitude => nil)
      expect(o.geom).to be_blank
    end
  end

  describe "private_geom" do
    it "should be set with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      expect(o.private_geom).not_to be_blank
    end
  
    it "should not be set without coords" do
      o = Observation.make!
      expect(o.private_geom).to be_blank
    end
  
    it "should change with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      expect(o.private_geom.y).to eq 1.0
      o.update_attributes(:latitude => 2)
      expect(o.private_geom.y).to eq 2.0
    end
  
    it "should go away with coords" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      o.update_attributes(:latitude => nil, :longitude => nil)
      expect(o.private_geom).to be_blank
    end

    it "should be set with geoprivacy" do
      o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::OBSCURED)
      expect(o.latitude).not_to eq 1.0
      expect(o.private_latitude).to eq 1.0
      expect(o.geom.y).not_to eq 1.0
      expect(o.private_geom.y).to eq 1.0
    end

    it "should be set without geoprivacy" do
      o = Observation.make!(:latitude => 1, :longitude => 1)
      expect(o.latitude).to eq 1.0
      expect(o.private_geom.y).to eq 1.0
    end
  end

  describe "query" do
    it "should filter by research grade" do
      r = make_research_grade_observation
      c = Observation.make!(:user => r.user)
      observations = Observation.query(:user => r.user, :quality_grade => Observation::RESEARCH_GRADE).all
      expect(observations).to include(r)
      expect(observations).not_to include(c)
    end

    it "should filter by comma-separated quality grades" do
      r = make_research_grade_observation
      expect( r ).to be_research_grade
      n = make_research_grade_candidate_observation
      expect( n ).to be_needs_id
      u = Observation.make!(:user => r.user)
      expect( u.quality_grade ).to eq Observation::CASUAL
      observations = Observation.query(:user => r.user, :quality_grade => "#{Observation::RESEARCH_GRADE},#{Observation::NEEDS_ID}").all
      expect(observations).to include(r)
      expect(observations).to include(n)
      expect(observations).not_to include(u)
    end

    it "should filter by taxon_ids[]" # except that it won't b/c multiple descendant taxon clauses is going to get rough fast
    it "should filter by taxon_ids[] if there's only one taxon" do
      taxon = Taxon.make!
      obs_of_taxon = Observation.make!(taxon: taxon)
      obs_not_of_taxon = Observation.make!(taxon: Taxon.make!)
      observations = Observation.query(taxon_ids: [taxon.id]).all
      expect( observations ).to include(obs_of_taxon)
      expect( observations ).not_to include(obs_not_of_taxon)
    end
    it "should filter by taxon_ids[] if all taxa are iconic" do
      load_test_taxa
      o1 = Observation.make!(taxon: @Aves)
      o2 = Observation.make!(taxon: @Amphibia)
      o3 = Observation.make!(taxon: @Animalia)
      expect( @Aves ).to be_is_iconic
      expect( @Amphibia ).to be_is_iconic
      expect( @Animalia ).to be_is_iconic
      observations = Observation.query(taxon_ids: [@Aves.id, @Amphibia.id]).all
      expect( observations ).to include(o1)
      expect( observations ).to include(o2)
      expect( observations ).not_to include(o3)
    end
  end

  describe "to_json" do
    it "should not include script tags" do
      o = Observation.make!(:description => "<script lang='javascript'>window.close()</script>")
      expect(o.to_json).not_to match(/<script/)
      expect(o.to_json(:viewer => o.user, 
        :force_coordinate_visibility => true,
        :include => [:user, :taxon, :iconic_taxon])).not_to match(/<script/)
      o = Observation.make!(:species_guess => "<script lang='javascript'>window.close()</script>")
      expect(o.to_json).not_to match(/<script/)
    end
  end

  describe "set_out_of_range" do
    before(:each) do
      @taxon = Taxon.make!
      @taxon_range = TaxonRange.make!(
        :taxon => @taxon, 
        :geom => "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))"
      )
    end
    it "should set to false if observation intersects known range" do
      o = Observation.make!(:taxon => @taxon, :latitude => 0.5, :longitude => 0.5)
      o.set_out_of_range
      expect(o.out_of_range).to eq false
    end
    it "should set to true if observation does not intersect known range" do
      o = Observation.make!(:taxon => @taxon, :latitude => 2, :longitude => 2)
      o.set_out_of_range
      expect(o.out_of_range).to eq true
    end
    it "should set to null if observation does not have a taxon" do
      o = Observation.make!
      o.set_out_of_range
      expect(o.out_of_range).to eq nil
    end
    it "should set to null if observation changes to have no taxon" do
      o = without_delay { Observation.make!(:taxon => @taxon, :latitude => 2, :longitude => 2) }
      expect(o).to be_out_of_range
      without_delay { o.update_attributes(taxon: nil) }
      o.reload
      expect(o.out_of_range).to eq nil
    end
    it "should set to null if taxon does not have a range" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t)
      o.set_out_of_range
      expect(o.out_of_range).to eq nil
    end
  end

  describe "out_of_range" do
    it "should get set to false immediately if taxon set to nil" do
      o = Observation.make!(:taxon => Taxon.make!, :out_of_range => true)
      expect(o).to be_out_of_range
      o.update_attributes(:taxon => nil)
      expect(o).not_to be_out_of_range
    end
  end

  describe "license" do
    it "should use the user's default observation license" do
      u = User.make!
      u.preferred_observation_license = "CC-BY-NC"
      u.save
      o = Observation.make!(:user => u, :license => nil)
      expect(o.license).to eq u.preferred_observation_license
    end

    it "should update default license when requested" do
      u = User.make!
      expect(u.preferred_observation_license).to be_blank
      o = Observation.make!(:user => u, :make_license_default => true, :license => Observation::CC_BY_NC)
      expect( o.license ).to eq Observation::CC_BY_NC
      u.reload
      expect(u.preferred_observation_license).to eq Observation::CC_BY_NC
    end

    it "should update all other observations when requested" do
      u = User.make!
      o1 = Observation.make!(:user => u, :license => nil)
      o2 = Observation.make!(:user => u, :license => nil)
      expect(o1.license).to be_blank
      o2.make_licenses_same = true
      o2.license = Observation::CC_BY_NC
      o2.save
      o1.reload
      expect(o1.license).to eq Observation::CC_BY_NC
    end

    it "should nilify if not a license" do
      o = Observation.make!(:license => Observation::CC_BY)
      o.update_attributes(:license => "on")
      o.reload
      expect(o.license).to be_blank
    end
  end

  describe "places" do
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
    it "should include places that do contain the positional_accuracy circle" do
      p = make_place_with_geom
      w = lat_lon_distance_in_meters(p.swlat, p.swlng, p.swlat, p.nelng)
      h = lat_lon_distance_in_meters(p.swlat, p.swlng, p.nelat, p.swlng)
      d = [w,h].min
      o = Observation.make!(:latitude => p.latitude, :longitude => p.longitude, :positional_accuracy => d/2)
      expect(o.places).to include p
    end
    it "should not include places that don't contain positional_accuracy circle" do
      p = make_place_with_geom
      w = lat_lon_distance_in_meters(p.swlat, p.swlng, p.swlat, p.nelng)
      h = lat_lon_distance_in_meters(p.swlat, p.swlng, p.nelat, p.swlng)
      d = [w,h].max
      o = Observation.make!(:latitude => p.latitude, :longitude => p.longitude, :positional_accuracy => d*2)
      expect(o.places).not_to include p
    end
  end

  describe "public_places" do
    it "should include system places that do contain the public_positional_accuracy circle" do
      p = make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))", admin_level: 1 )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude, taxon: make_threatened_taxon )
      expect( o.public_places ).to include p
    end
    it "should not include system places that don't contain public_positional_accuracy circle" do
      p = make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0)))", admin_level: 1 )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude, taxon: make_threatened_taxon )
      expect( o.public_places ).not_to include p
    end
  end

  describe "update_stats" do
    it "should not consider outdated identifications as agreements" do
      o = Observation.make!(:taxon => Taxon.make!)
      old_ident = Identification.make!(:observation => o, :taxon => o.taxon)
      new_ident = Identification.make!(:observation => o, :user => old_ident.user)
      o.reload
      o.update_stats
      o.reload
      old_ident.reload
      expect(old_ident).not_to be_current
      expect(o.num_identification_agreements).to eq(0)
      expect(o.num_identification_disagreements).to eq(1)
    end
  end

  describe "update_stats_for_observations_of" do
    it "should work" do
      parent = Taxon.make!
      child = Taxon.make!
      o = Observation.make!(:taxon => parent)
      i1 = Identification.make!(:observation => o, :taxon => child)
      o.reload
      expect(o.num_identification_agreements).to eq(0)
      expect(o.num_identification_disagreements).to eq(1)
      child.update_attributes(:parent => parent)
      Observation.update_stats_for_observations_of(parent)
      o.reload
      expect(o.num_identification_agreements).to eq(1)
      expect(o.num_identification_disagreements).to eq(0)
    end

    it "should work" do
      parent = Taxon.make!
      child = Taxon.make!
      o = Observation.make!(:taxon => parent)
      i1 = Identification.make!(:observation => o, :taxon => child)
      o.reload
      expect(o.community_taxon).to be_blank
      child.update_attributes(:parent => parent)
      Observation.update_stats_for_observations_of(parent)
      o.reload
      expect(o.community_taxon).not_to be_blank
    end
  end

  describe "nested observation_field_values" do
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
      expect { o.update_attributes(attrs) }.not_to raise_error
      o.reload
      expect(o.observation_field_values.last.observation_field_id).to eq(of.id)
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
      expect { o.update_attributes(attrs) }.not_to raise_error
      o.reload
      expect(o.observation_field_values).to be_blank
    end
  end

  describe "taxon updates" do
    before(:each) { enable_elastic_indexing(UpdateAction) }
    after(:each) { disable_elastic_indexing(UpdateAction) }

    it "should generate an update" do
      t = Taxon.make!
      s = Subscription.make!(:resource => t)
      o = Observation.make(:taxon => t)
      without_delay do
        o.save!
      end
      u = UpdateSubscriber.last
      expect(u).not_to be_blank
      expect(u.update_action.notifier).to eq(o)
      expect(u.subscriber).to eq(s.user)
    end

    it "should generate an update for descendent taxa" do
      t1 = Taxon.make!
      t2 = Taxon.make!(:parent => t1)
      s = Subscription.make!(:resource => t1)
      o = Observation.make(:taxon => t2)
      without_delay do
        o.save!
      end
      u = UpdateSubscriber.last
      expect(u).not_to be_blank
      expect(u.update_action.notifier).to eq(o)
      expect(u.subscriber).to eq(s.user)
    end

    # This ended up being really annoying for people subscribed to high level
    # taxa like Anisoptera. Still feel like there's a better way to do this than
    # triggering it on create
    # it "should generate an update for an observation that changed to the subscribed taxon" do
    #   t = Taxon.make!
    #   s = Subscription.make!(:resource => t)
    #   Update.delete_all
    #   o = without_delay {Observation.make!}
    #   Update.count.should eq 0
    #   without_delay do
    #     o.update_attributes(:taxon => t)
    #   end
    #   u = Update.last
    #   u.should_not be_blank
    #   u.notifier.should eq(o)
    #   u.subscriber.should eq(s.user)
    # end
  end


  describe "place updates" do
    before(:each) { enable_elastic_indexing(UpdateAction) }
    after(:each) { disable_elastic_indexing(UpdateAction) }

    describe "for places that cross the date line" do
      let(:place) {
        # crude shape that includes the north and south island of New Zealand
        # (west of 180) and the Chathams (east of 180)
        wkt = <<-WKT
          MULTIPOLYGON
            (
              (
                (
                  -177.374267578125 -43.4449429552612,-177.396240234375
                  -44.5278427984555,-175.1220703125
                  -44.629573191951,-174.9462890625
                  -43.4289879234416,-177.374267578125 -43.4449429552612
                )
              ),(
                (
                  180 -33.9433599465788,179.736328125
                  -48.1074311884804,164.970703125 -47.8131545175277,165.234375
                  -33.3580616127788,180 -33.9433599465788
                )
              )
            )
        WKT
        make_place_with_geom( ewkt: wkt.gsub(/\s+/, ' ') )
      }
      before do
        expect( place.straddles_date_line? ).to be true
        @subscription = Subscription.make!( resource: place )
        @christchurch_lat = -43.603555
        @christchurch_lon = 172.652311
      end
      it "should generate" do
        o = without_delay do
          Observation.make!( latitude: @christchurch_lat, longitude: @christchurch_lon )
        end
        expect( o.public_places.map(&:id) ).to include place.id
        expect( @subscription.user.update_subscribers.last.update_action.notifier ).to eq o
      end
      it "should not generate for observations outside of that place" do
        o = without_delay do
          Observation.make!(:latitude => -1 * @christchurch_lat, :longitude => @christchurch_lon)
        end
        expect(@subscription.user.update_subscribers).to be_blank
      end
    end
  end

  describe "update_for_taxon_change" do
    before(:each) do
      @taxon_swap = TaxonSwap.make
      @input_taxon = Taxon.make!( rank: Taxon::FAMILY )
      @output_taxon = Taxon.make!( rank: Taxon::FAMILY )
      @taxon_swap.add_input_taxon(@input_taxon)
      @taxon_swap.add_output_taxon(@output_taxon)
      @taxon_swap.save!
      @obs_of_input = Observation.make!(:taxon => @input_taxon)
    end

    it "should add new identifications" do
      expect(@obs_of_input.identifications.size).to eq(1)
      expect(@obs_of_input.identifications.first.taxon).to eq(@input_taxon)
      Observation.update_for_taxon_change(@taxon_swap, @output_taxon)
      @obs_of_input.reload
      expect(@obs_of_input.identifications.size).to eq(2)
      expect(@obs_of_input.identifications.detect{|i| i.taxon_id == @output_taxon.id}).not_to be_blank
    end

    it "should not update old identifications" do
      old_ident = @obs_of_input.identifications.first
      expect(old_ident.taxon).to eq(@input_taxon)
      Observation.update_for_taxon_change(@taxon_swap, @output_taxon)
      old_ident.reload
      expect(old_ident.taxon).to eq(@input_taxon)
    end
  end

  describe "reassess_coordinates_for_observations_of" do
    it "should obscure coordinates for observations of threatened taxa" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t, :latitude => 1, :longitude => 1)
      cs = ConservationStatus.make!(:taxon => t)
      expect(o).not_to be_coordinates_obscured
      Observation.reassess_coordinates_for_observations_of(t)
      o.reload
      expect(o).to be_coordinates_obscured
    end

    it "should obscure coordinates for observations with dissenting identifications of threatened taxa" do
      load_test_taxa
      o = make_research_grade_observation( taxon: @Calypte_anna )
      2.times { Identification.make!( observation: o, taxon: @Calypte_anna ) }
      Identification.make!( observation: o, taxon: @Pseudacris_regilla )
      expect( o ).not_to be_coordinates_obscured
      cs = ConservationStatus.make!( taxon: @Pseudacris_regilla )
      Observation.reassess_coordinates_for_observations_of( @Pseudacris_regilla )
      o.reload
      expect( o ).to be_coordinates_obscured
    end

    it "should not unobscure coordinates of obs of unthreatened if geoprivacy is set" do
      t = Taxon.make!
      o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::OBSCURED, :taxon => t)
      old_lat = o.latitude
      expect(o).to be_coordinates_obscured
      Observation.reassess_coordinates_for_observations_of(t)
      o.reload
      expect(o).to be_coordinates_obscured
      expect(o.latitude).to eq(old_lat)
    end

    it "should change the place_guess" do
      p = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
      t = Taxon.make!
      place_guess = "somewhere awesome"
      o = Observation.make!( taxon: t, latitude: p.latitude, longitude: p.longitude, place_guess: place_guess )
      cs = ConservationStatus.make!( taxon: t )
      expect( o.place_guess ).to eq place_guess
      Observation.reassess_coordinates_for_observations_of( t )
      o.reload
      expect( o.place_guess ).not_to be =~ /#{place_guess}/
      expect( o.place_guess ).to be =~ /#{p.name}/
    end
  end

  describe "queue_for_sharing" do
    it "should queue a job if twitter ProviderAuthorization present" do
      pa = ProviderAuthorization.make!(:provider_name => "twitter")
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_twitter%"])).to be_blank
      o = Observation.make!(:user => pa.user)
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_twitter%"])).not_to be_blank
    end
    it "should queue a job if facebook ProviderAuthorization present" do
      pa = ProviderAuthorization.make!(:provider_name => "facebook")
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_facebook%"])).to be_blank
      o = Observation.make!(:user => pa.user)
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_facebook%"])).not_to be_blank
    end
    it "should not queue a job if no ProviderAuthorizations present" do
      o = Observation.make!
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_facebook%"])).to be_blank
    end
    it "should not queue a twitter job if twitter_sharing is 0" do
      pa = ProviderAuthorization.make!(:provider_name => "twitter")
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_twitter%"])).to be_blank
      o = Observation.make!(:user => pa.user, :twitter_sharing => "0")
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_twitter%"])).to be_blank
    end
    it "should not queue a facebook job if facebook_sharing is 0" do
      pa = ProviderAuthorization.make!(:provider_name => "facebook")
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{pa.user_id}\n%share_on_facebook%"])).to be_blank
      o = Observation.make!(:user => pa.user, :facebook_sharing => "0")
      expect(Delayed::Job.where(["handler LIKE ?", "%user_id: #{o.user_id}\n%share_on_facebook%"])).to be_blank
    end
  end

  describe "captive" do
    it "should vote yes on the wild quality metric if 1" do
      o = Observation.make!(:captive_flag => "1")
      expect(o.quality_metrics).not_to be_blank
      expect(o.quality_metrics.first.user).to eq(o.user)
      expect(o.quality_metrics.first).not_to be_agree
    end

    it "should vote no on the wild quality metric if 0 and metric exists" do
      o = Observation.make!(:captive_flag => "1")
      expect(o.quality_metrics).not_to be_blank
      o.update_attributes(:captive_flag => "0")
      expect(o.quality_metrics.first).to be_agree
    end

    it "should not alter quality metrics if nil" do
      o = Observation.make!(:captive_flag => nil)
      expect(o.quality_metrics).to be_blank
    end

    it "should not alter quality metrics if 0 and not metrics exist" do
      o = Observation.make!(:captive_flag => "0")
      expect(o.quality_metrics).to be_blank
    end
  end

  describe "merge" do
    let(:user) { User.make! }
    let(:reject) { Observation.make!(:user => user) }
    let(:keeper) { Observation.make!(:user => user) }

    it "should destroy the reject" do
      keeper.merge(reject)
      expect(Observation.find_by_id(reject.id)).to be_blank
    end

    it "should preserve photos" do
      op = ObservationPhoto.make!(:observation => reject)
      keeper.merge(reject)
      op.reload
      expect(op.observation).to eq(keeper)
    end

    it "should preserve comments" do
      c = Comment.make!(:parent => reject)
      keeper.merge(reject)
      c.reload
      expect(c.parent).to eq(keeper)
    end

    it "should preserve identifications" do
      i = Identification.make!(:observation => reject)
      keeper.merge(reject)
      i.reload
      expect(i.observation).to eq(keeper)
    end

    it "should mark duplicate identifications as not current" do
      t = Taxon.make!
      without_delay do
        reject.update_attributes(:taxon => t)
        keeper.update_attributes(:taxon => t)
      end
      keeper.merge(reject)
      idents = keeper.identifications.where(:user_id => keeper.user_id).order('id asc')
      expect(idents.size).to eq(2)
      expect(idents.first).not_to be_current
      expect(idents.last).to be_current
    end
  end

  describe "component_cache_key" do
    it "should be the same regardless of option order" do
      k1 = Observation.component_cache_key(111, :for_owner => true, :locale => :en)
      k2 = Observation.component_cache_key(111, :locale => :en, :for_owner => true)
      expect(k1).to eq(k2)
    end
  end

  describe "dynamic taxon getters" do
    it "should not interfere with taxon_id"
    it "should return genus"
  end

  describe "dynamic place getters" do
    it "should return place state" do
      p = make_place_with_geom(:place_type => Place::PLACE_TYPE_CODES['State'])
      o = Observation.make!(:latitude => p.latitude, :longitude => p.longitude)
      expect(o.intersecting_places).not_to be_blank
      expect(o.place_state).to eq p
      expect(o.place_state_name).to eq p.name
    end
  end

  describe "community taxon" do

    it "should be set if user has opted out" do
      u = User.make!(:prefers_community_taxa => false)
      o = Observation.make!(:user => u)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).not_to be_blank
    end

    it "should be set if user has opted out and community agrees with user" do
      u = User.make!(:prefers_community_taxa => false)
      o = Observation.make!(:taxon => Taxon.make!, :user => u)
      i1 = Identification.make!(:observation => o, :taxon => o.taxon)
      o.reload
      expect(o.community_taxon).to eq o.taxon
    end

    it "should be set if observation is opted out" do
      o = Observation.make!(:prefers_community_taxon => false)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).not_to be_blank
    end

    it "should be set if observation is opted in but user is opted out" do
      u = User.make!(:prefers_community_taxa => false)
      o = Observation.make!(:prefers_community_taxon => true, :user => u)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).to eq i1.taxon
    end

    it "should be set when preference set to true" do
      o = Observation.make!(:prefers_community_taxon => false)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to be_blank
      o.update_attributes(:prefers_community_taxon => true)
      o.reload
      expect(o.community_taxon).to eq(i1.taxon)
    end

    it "should not be unset when preference set to false" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).to eq(i1.taxon)
      o.update_attributes(:prefers_community_taxon => false)
      o.reload
      expect(o.community_taxon).not_to be_blank
    end

    it "should set the taxon" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to eq o.community_taxon
    end

    it "should set the species_guess" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.species_guess).to eq o.community_taxon.name
    end

    it "should set the iconic taxon" do
      o = Observation.make!
      expect(o.iconic_taxon).to be_blank
      iconic_taxon = Taxon.make!(:is_iconic => true, :rank => "family")
      i1 = Identification.make!(:observation => o, :taxon => Taxon.make!(:parent => iconic_taxon, :rank => "genus"))
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      expect(i1.taxon.iconic_taxon).to eq iconic_taxon
      o.reload
      expect(o.taxon).to eq i1.taxon
      expect(o.iconic_taxon).to eq iconic_taxon
    end

    it "should not set the taxon if the user has opted out" do
      u = User.make!(:prefers_community_taxa => false)
      o = Observation.make!(:user => u)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to be_blank
    end

    it "should not set the taxon if the observation is opted out" do
      o = Observation.make!(:prefers_community_taxon => false)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to be_blank
    end

    it "should change the taxon to the owner's identication when observation opted out" do
      owner_taxon = Taxon.make!
      o = Observation.make!(:taxon => owner_taxon)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).to eq(i1.taxon)
      expect(o.taxon).to eq o.community_taxon
      o.update_attributes(:prefers_community_taxon => false)
      o.reload
      expect(o.taxon).to eq owner_taxon
    end

    it "should set the species_guess when opted out" do
      owner_taxon = Taxon.make!
      o = Observation.make!(:taxon => owner_taxon)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      i3 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).to eq(i1.taxon)
      expect(o.taxon).to eq o.community_taxon
      o.update_attributes(:prefers_community_taxon => false)
      o.reload
      expect(o.species_guess).to eq owner_taxon.name
    end

    it "should set the taxon if observation is opted in but user is opted out" do
      u = User.make!(:prefers_community_taxa => false)
      o = Observation.make!(:prefers_community_taxon => true, :user => u)
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.taxon).to eq o.community_taxon
    end

    it "should not be set if there is only one current identification" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o, :user => o.user)
      i2 = Identification.make!(:observation => o, :user => o.user)
      o.reload
      expect(o.community_taxon).to be_blank
    end

    it "should not be set for 2 roots" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o)
      o.reload
      expect(o.community_taxon).to be_blank
    end

    it "should be set to Life for two phyla" do
      load_test_taxa
      o = Observation.make!
      i1 = Identification.make!(:observation => o, :taxon => @Animalia)
      i2 = Identification.make!(:observation => o, :taxon => @Plantae)
      o.reload
      expect(o.community_taxon).to eq @Life
    end


    it "change should be triggered by changing the taxon" do
      load_test_taxa
      o = Observation.make!
      i1 = Identification.make!(:observation => o, :taxon => @Animalia)
      expect(o.community_taxon).to be_blank
      o = Observation.find(o.id)
      o.update_attributes(:taxon => @Plantae)
      expect(o.community_taxon).not_to be_blank
      expect(o.identifications.count).to eq 2
    end
    
    # it "change should trigger change in observation stats" do

    # end

    it "should obscure the observation if set to a threatened taxon if the owner has an ID but the community confirms a descendant" do
      p = Taxon.make!(:rank => "genus")
      t = Taxon.make!(:parent => p, :rank => "species")
      cs = ConservationStatus.make!(:taxon => t)
      o = Observation.make!(:latitude => 1, :longitude => 1, :taxon => p)
      expect(o).not_to be_coordinates_obscured
      expect(o.taxon).not_to be_blank
      i1 = Identification.make!(:taxon => t, :observation => o)
      i2 = Identification.make!(:taxon => t, :observation => o)
      o.reload
      expect(o.community_taxon).to eq t
      expect(o).to be_coordinates_obscured
    end

    it "should obscure the observation if set to a threatened taxon but the owner has no ID" do
      cs = ConservationStatus.make!
      t = cs.taxon
      o = Observation.make!(:latitude => 1, :longitude => 1)
      expect(o.taxon).to be_blank
      i1 = Identification.make!(:taxon => t, :observation => o)
      i2 = Identification.make!(:taxon => t, :observation => o)
      o.reload
      expect(o.taxon).to eq t
      expect(o).to be_coordinates_obscured
    end

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
        expect(@o.community_taxon).to eq @g1
      end

      it "s1 s1 g1" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @g1)
        @o.reload
        expect(@o.community_taxon).to eq @g1
      end

      it "s1 s1 s1 g1" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @g1)
        @o.reload
        expect(@o.community_taxon).to eq @s1
      end

      it "ss1 ss1 ss2 ss2" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s2)
        Identification.make!(:observation => @o, :taxon => @s2)
        @o.reload
        expect(@o.community_taxon).to eq @g1
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
        expect(@o.community_taxon).to eq @s2
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
        expect(@o.community_taxon).to eq @g1
      end

      it "f g1 s1 (should not taxa with only one ID to be the community taxon)" do
        Identification.make!(:observation => @o, :taxon => @f)
        Identification.make!(:observation => @o, :taxon => @g1)
        Identification.make!(:observation => @o, :taxon => @s1)
        @o.reload
        expect(@o.community_taxon).to eq @g1
      end

      it "f f g1 s1" do
        Identification.make!(:observation => @o, :taxon => @f)
        Identification.make!(:observation => @o, :taxon => @f)
        Identification.make!(:observation => @o, :taxon => @g1)
        Identification.make!(:observation => @o, :taxon => @s1)
        @o.reload
        expect(@o.community_taxon).to eq @g1
      end

      it "s1 s1 f f" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @f)
        Identification.make!(:observation => @o, :taxon => @f)
        @o.reload
        expect(@o.community_taxon).to eq @f
      end
    end
  end

  describe "fields_addable_by?" do
    it "should default to true for anyone" do
      expect(Observation.make!.fields_addable_by?(User.make!)).to be true
    end

    it "should be false for nil user" do
      expect(Observation.make!.fields_addable_by?(nil)).to be false
    end

    it "should be true for curators if curators preferred" do
      c = make_curator
      u = User.make!(:preferred_observation_fields_by => User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS)
      o = Observation.make!(:user => u)
      expect(o.fields_addable_by?(c)).to be true
    end

    it "should be true for curators by default" do
      c = make_curator
      u = User.make!
      o = Observation.make!(:user => u)
      expect(o.fields_addable_by?(c)).to be true
    end

    it "should be false for curators if no editing preferred" do
      c = make_curator
      u = User.make!(:preferred_observation_fields_by => User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER)
      o = Observation.make!(:user => u)
      expect(o.fields_addable_by?(c)).to be false
    end

    it "should be false for everyone other than the observer if no editing preferred" do
      other = User.make!
      u = User.make!(:preferred_observation_fields_by => User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER)
      o = Observation.make!(:user => u)
      expect(o.fields_addable_by?(other)).to be false
    end

    it "should be true for the observer if no editing preferred" do
      u = User.make!(:preferred_observation_fields_by => User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER)
      o = Observation.make!(:user => u)
      expect(o.fields_addable_by?(u)).to be true
    end
  end

  describe "mappable" do
    it "should be mappable with lat/long" do
      expect(Observation.make!(latitude: 1.1, longitude: 2.2)).to be_mappable
    end

    it "should not be mappable without lat/long" do
      expect(Observation.make!).not_to be_mappable
    end

    it "should not be mappable with a terrible accuracy" do
      o = Observation.make!(latitude: 1.1, longitude: 2.2)
      o.update_attributes( positional_accuracy: o.uncertainty_cell_diagonal_meters + 1 )
      expect( o ).not_to be_mappable
    end

    it "should not be mappable if captive" do
      expect(Observation.make!(latitude: 1.1, longitude: 2.2, captive: true)).not_to be_mappable
    end

    it "should not be mappable when adding captive metric" do
      o = Observation.make!(latitude: 1.1, longitude: 2.2)
      expect(o.mappable?).to be true
      QualityMetric.make!(observation: o, metric: QualityMetric::WILD, agree: false)
      expect(o.mappable?).to be false
    end

    it "should update mappable when captive metric is deleted" do
      o = Observation.make!(latitude: 1.1, longitude: 2.2)
      expect(o.mappable?).to be true
      q = QualityMetric.make!(observation: o, metric: QualityMetric::WILD, agree: false)
      expect(o.mappable?).to be false
      q.destroy
      expect(o.reload.mappable?).to be true
    end

    it "should not be mappable with an inaccurate location" do
      o = Observation.make!(latitude: 1.1, longitude: 2.2)
      expect(o.mappable?).to be true
      QualityMetric.make!(observation: o, metric: QualityMetric::LOCATION, agree: false)
      expect(o.mappable?).to be false
    end

    it "should update mappable after multiple quality metrics are added" do
      o = Observation.make!(latitude: 1.1, longitude: 2.2)
      expect(o.mappable?).to be true
      QualityMetric.make!(observation: o, metric: QualityMetric::LOCATION, agree: true)
      expect(o.mappable?).to be true
      QualityMetric.make!(observation: o, metric: QualityMetric::WILD, agree: false)
      expect(o.mappable?).to be false
    end

    it "should default accuracy of obscured observations to uncertainty_cell_diagonal_meters" do
      o = Observation.make!(geoprivacy: Observation::OBSCURED, latitude: 1.1, longitude: 2.2)
      expect(o.coordinates_obscured?).to be true
      expect(o.calculate_public_positional_accuracy).to eq o.uncertainty_cell_diagonal_meters
    end

    it "should set public accuracy to the greater of accuracy and M_TO_OBSCURE_THREATENED_TAXA" do
      lat, lon = [ 1.1, 2.2 ]
      uncertainty_cell_diagonal_meters = Observation.uncertainty_cell_diagonal_meters( lat, lon )
      o = Observation.make!(geoprivacy: Observation::OBSCURED, latitude: lat, longitude: lon,
        positional_accuracy: uncertainty_cell_diagonal_meters + 1)
      expect(o.calculate_public_positional_accuracy).to eq o.uncertainty_cell_diagonal_meters + 1
    end

    it "should set public accuracy to accuracy" do
      expect(Observation.make!(positional_accuracy: 10).public_positional_accuracy).to eq 10
    end

    it "should set public accuracy to nil if accuracy is nil" do
      expect(Observation.make!(positional_accuracy: nil).public_positional_accuracy).to be_nil
    end

    it "should be mappable for obscured" do
      o = make_research_grade_observation( geoprivacy: Observation::OBSCURED )
      expect( o ).to be_mappable
    end
    it "should be mappable for threatened taxa" do
      o = make_observation_of_threatened
      expect( o ).to be_mappable
    end
  end

  describe "observations_places" do
    it "should generate observations_places after save" do
      p = make_place_with_geom
      o = Observation.make!
      expect(o.observations_places.length).to eq 0
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be false
      o.latitude = p.latitude
      o.longitude = p.longitude
      o.save
      o.reload
      expect(o.observations_places.length).to be >= 1
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be true
    end

    it "deletes its observations_places on destroy" do
      p = make_place_with_geom
      o = Observation.make!(latitude: p.latitude, longitude: p.longitude)
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be true
      o.destroy
      expect(ObservationsPlace.exists?(observation_id: o.id, place_id: p.id)).to be false
    end
  end

  describe "coordinate transformation", :focus => true  do
    let(:proj4_nztm) {
      "+proj=tmerc +lat_0=0 +lon_0=173 +k=0.9996 +x_0=1600000 +y_0=10000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
    }
    subject { Observation.make }
    
    it "requires geo_x if geo_y is present" do
      subject.geo_y = 5413457.7
      subject.valid?
      expect(subject.errors[:geo_x].size).to eq(1)
    end

    it "requires geo_x to be a number" do
      subject.geo_x = "test"
      subject.valid?
      expect(subject.errors[:geo_x].size).to eq(1)
    end

    it "requires geo_y if geo_x is present" do
      subject.geo_x = 1528677.3
      subject.valid?
      expect(subject.errors[:geo_y].size).to eq(1)
    end

    it "requires geo_y to be a number" do
      subject.geo_y = "test"
      subject.valid?
      expect(subject.errors[:geo_y].size).to eq(1)
    end

    # FIXME: this is fragile
    it "requires coordinate_system to be valid" do
      subject.coordinate_system = "some_invalid_value"
      subject.valid?
      expect(subject.errors[:coordinate_system].size).to eq(1)
    end

    it "sets lat lng" do
      subject.geo_y = 5413457.7
      subject.geo_x = 1528677.3
      subject.coordinate_system = proj4_nztm
      subject.save!
      expect(subject.latitude).to be_within(0.0000001).of(-41.4272781531)
      expect(subject.longitude).to be_within(0.0000001).of(172.1464131267)
    end

  end

  describe "interpolate_coordinates" do
    it "should use means" do
      u = User.make!
      p = Observation.make!(user: u, latitude: 0, longitude: 0, observed_on_string: "2014-06-02 00:00", positional_accuracy: 100)
      n = Observation.make!(user: u, latitude: 1, longitude: 1, observed_on_string: "2014-06-02 02:00", positional_accuracy: 100)
      o = Observation.make!(user: u, observed_on_string: "2014-06-02 01:00")
      o.interpolate_coordinates
      expect( o.latitude ).to eq 0.5
      expect( o.longitude ).to eq 0.5
    end

    it "should use weight by time" do
      u = User.make!
      p = Observation.make!(user: u, latitude: 0, longitude: 0, observed_on_string: "2014-06-02 00:00", positional_accuracy: 100)
      n = Observation.make!(user: u, latitude: 1, longitude: 1, observed_on_string: "2014-06-02 02:00", positional_accuracy: 100)
      o = Observation.make!(user: u, observed_on_string: "2014-06-02 01:59")
      o.interpolate_coordinates
      expect( o.latitude.to_f ).to be > 0.5
      expect( o.longitude.to_f ).to be > 0.5
    end
  end

  describe "timezone_object" do
    it "returns nil when given nil" do
      o = Observation.make!( )
      o.update_column(:time_zone, nil)
      o.update_column(:zic_time_zone, nil)
      expect( o.time_zone ).to be nil
      expect( o.timezone_object ).to be nil
    end
  end

  describe "reviewed_by?" do
    it "knows who it was reviewed by" do
      o = Observation.make!
      expect( o.reviewed_by?( o.user ) ).to be false
      r = ObservationReview.make!(observation: o, user: o.user)
      expect( o.reviewed_by?( o.user ) ).to be true
    end

    it "doesn't count unreviews" do
      o = Observation.make!
      expect( o.reviewed_by?( o.user ) ).to be false
      r = ObservationReview.make!(observation: o, user: o.user, reviewed: false)
      expect( o.reviewed_by?( o.user ) ).to be false
    end
  end

  describe "random_neighbor_lat_lon", disabled: ENV["TRAVIS_CI"] do
    it "randomizes values within a 0.2 degree square" do
      lat_lons = [ [ 0, 0 ], [ 0.001, 0.001 ], [ 0.199, 0.199 ] ]
      values = [ ]
      100.times do
        lat_lons.each do |ll|
          rand_ll = Observation.random_neighbor_lat_lon( ll[0], ll[1] )
          # random values should be in range
          expect(rand_ll[0]).to be_between(0, 0.2)
          expect(rand_ll[1]).to be_between(0, 0.2)
          # values should be different from their original
          expect(rand_ll[0]).not_to be(ll[0])
          expect(rand_ll[1]).not_to be(ll[1])
          values += rand_ll
        end
      end
      average = values.inject(:+) / values.size.to_f
      # we expect the center of the cluster to be around 0.1, 0.1
      expect(average).to be_between(0.095, 0.105)
    end
  end

  describe "mentions" do
    it "knows what users have been mentioned" do
      u = User.make!
      o = Observation.make!(description: "hey @#{ u.login }")
      expect( o.mentioned_users ).to eq [ u ]
    end

    it "generates mention updates" do
      u = User.make!
      o = without_delay { Observation.make!(description: "hey @#{ u.login }") }
      expect( UpdateAction.where(notifier: o, notification: "mention").count ).to eq 1
      expect( UpdateAction.where(notifier: o, notification: "mention").first.
        update_subscribers.first.subscriber ).to eq u
    end
  end

  describe "dedupe_for_user" do
    before do
      @obs = Observation.make!(
        observed_on_string: "2015-01-01", 
        latitude: 1, 
        longitude: 1, 
        taxon: Taxon.make!
      )
      @dupe = Observation.make!(
        observed_on_string: @obs.observed_on_string, 
        latitude: @obs.latitude, 
        longitude: @obs.longitude, 
        taxon: @obs.taxon, 
        user: @obs.user
      )
    end
    it "should remove duplicates" do
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).to be_blank
    end
    it "should remove duplicates with obscured coordinates" do
      @dupe.update_attributes(geoprivacy: Observation::OBSCURED)
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).to be_blank
    end
    it "should not assume null datetimes are the same" do
      @obs.update_attributes(observed_on_string: nil)
      @dupe.update_attributes(observed_on_string: nil)
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
    it "should not assume blank datetimes are the same" do
      @obs.update_attributes(observed_on_string: '')
      @dupe.update_attributes(observed_on_string: '')
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
    it "should not assume null coordinates are the same" do
      @obs.update_attributes(latitude: nil, longitude: nil)
      @dupe.update_attributes(latitude: nil, longitude: nil)
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
    it "should not assume null taxa are the same" do
      @obs.update_attributes(taxon: nil)
      @dupe.update_attributes(taxon: nil)
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
  end
end
