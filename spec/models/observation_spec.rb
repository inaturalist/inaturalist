# encoding: UTF-8
require File.dirname(__FILE__) + '/../spec_helper.rb'

include ElasticStub

describe Observation do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to(:community_taxon).class_name 'Taxon' }
  it { is_expected.to belong_to(:iconic_taxon).class_name('Taxon').with_foreign_key 'iconic_taxon_id' }
  it { is_expected.to belong_to :oauth_application }
  it { is_expected.to belong_to(:site).inverse_of :observations }
  it { is_expected.to have_many(:observation_photos).dependent(:destroy).inverse_of :observation }
  it { is_expected.to have_many(:photos).through :observation_photos }
  it { is_expected.to have_many(:listed_taxa).with_foreign_key 'last_observation_id' }
  it { is_expected.to have_many(:first_listed_taxa).class_name('ListedTaxon').with_foreign_key 'first_observation_id' }
  it { is_expected.to have_many(:first_check_listed_taxa).class_name('ListedTaxon').with_foreign_key 'first_observation_id' }
  it { is_expected.to have_many(:comments).dependent :destroy }
  it { is_expected.to have_many(:annotations).dependent :destroy }
  it { is_expected.to have_many(:identifications).dependent :destroy }
  it { is_expected.to have_many(:project_observations).dependent :destroy }
  it { is_expected.to have_many(:project_observations_with_changes).class_name 'ProjectObservation' }
  it { is_expected.to have_many(:projects).through :project_observations }
  it { is_expected.to have_many(:quality_metrics).dependent :destroy }
  it { is_expected.to have_many(:observation_field_values).dependent(:destroy).inverse_of :observation }
  it { is_expected.to have_many(:observation_fields).through :observation_field_values }
  it { is_expected.to have_many :observation_links }
  it { is_expected.to have_and_belong_to_many :posts }
  it { is_expected.to have_many(:observation_sounds).dependent(:destroy).inverse_of :observation }
  it { is_expected.to have_many(:sounds).through :observation_sounds }
  it { is_expected.to have_many :observations_places }
  it { is_expected.to have_many(:observation_reviews).dependent :destroy }
  it { is_expected.to have_many(:confirmed_reviews).class_name 'ObservationReview' }
  context 'when geo_x present' do
    subject { Observation.new geo_x: 1 }
    it { is_expected.to validate_presence_of :geo_y }
  end
  context 'when geo_y present' do
    subject { Observation.new geo_y: 1 }
    it { is_expected.to validate_presence_of :geo_x }
  end
  it { is_expected.to validate_numericality_of(:geo_y).allow_nil.with_message "should be a number" }
  it { is_expected.to validate_numericality_of(:geo_x).allow_nil.with_message "should be a number" }
  it { is_expected.to validate_presence_of :user_id }
  it { is_expected.to validate_numericality_of(:latitude).allow_nil.is_less_than(90).is_greater_than -90 }
  it { is_expected.to validate_length_of(:species_guess).is_at_most(256).allow_blank }
  it { is_expected.to validate_length_of(:place_guess).is_at_most(256).allow_blank }
  it do
    is_expected.to validate_numericality_of(:longitude).allow_nil.is_less_than_or_equal_to(180)
                                                                 .is_greater_than_or_equal_to -180
  end

  before(:all) do
    DatabaseCleaner.clean_with(:truncation, except: %w[spatial_ref_sys])
  end

  elastic_models( Observation, Taxon )

  describe "creation" do
    subject { build :observation }

    describe "parses and sets time" do
      context "with observed_on_string" do
        subject { build_stubbed :observation, :without_times }

        before do |spec|
          subject.observed_on_string = spec.metadata[:time]
          subject.run_callbacks :validation
        end

        it "should be in the past", time: 'April 1st 1994 at 1am'  do
          expect(subject.observed_on).to be <= Date.today
        end

        it "should properly set date and time", time: 'April 1st 1994 at 1am' do
          Time.use_zone(subject.time_zone) do
            expect(subject.observed_on.year).to eq 1994
            expect(subject.observed_on.month).to eq 4
            expect(subject.observed_on.day).to eq 1
            expect(subject.time_observed_at.hour).to eq 1
          end
        end

        it "should parse time from strings like October 30, 2008 10:31PM", time: "October 30, 2008 10:31PM" do
          expect(subject.time_observed_at.in_time_zone(subject.time_zone).hour).to eq 22
        end

        it "should parse time from strings like 2011-12-23T11:52:06-0500", time: "2011-12-23T11:52:06-0500" do
          expect(subject.time_observed_at.in_time_zone(subject.time_zone).hour).to eq 11
        end

        it "should parse time from strings like 2011-12-23 11:52:06 -05", time: "2011-12-23 11:52:06 -05" do
          expect(subject.time_observed_at.in_time_zone(subject.time_zone).hour ).to eq 11
        end

        it "should parse time from strings like 2011-12-23T11:52:06.123", time: "2011-12-23T11:52:06.123" do
          expect(subject.time_observed_at.in_time_zone(subject.time_zone).hour).to eq 11
        end

        it "should parse time and zone from July 9, 2012 7:52:39 AM ACST", time: "July 9, 2012 7:52:39 AM ACST" do
          expect(subject.time_observed_at.in_time_zone(subject.time_zone).hour).to eq 7
          expect(subject.time_zone).to eq ActiveSupport::TimeZone['Adelaide'].name
        end

        it "should handle unparsable times gracefully", time: "2013-03-02, 1430hrs" do
          expect(subject.observed_on.day).to eq 2
        end

        it "should not save a time if one wasn't specified", time: "April 2 2008" do
          expect(subject.time_observed_at).to be_blank
        end

        it "should not save a time for 'today'", time: "today" do
          expect(subject.time_observed_at).to be(nil)
        end

        it "should parse a time zone from a code", time: 'October 30, 2008 10:31PM EST' do
          expect(subject.time_zone).to eq ActiveSupport::TimeZone['Eastern Time (US & Canada)'].name
        end

        it "should parse time zone from strings like '2011-12-23T11:52:06-0500'", time: "2011-12-23T11:52:06-0500" do
          expect(subject.time_zone).not_to be_blank
          expect(ActiveSupport::TimeZone[subject.time_zone].formatted_offset).to eq "-05:00"
        end

        it "should not save relative dates/times like 'this morning'", time: "this morning" do
          expect(subject.observed_on_string.match('this morning')).to be(nil)
        end

        it "should preserve observed_on_string if it did NOT contain a relative time descriptor", time: "April 22 2008" do
          expect(subject.observed_on_string).to eq "April 22 2008"
        end

        it "should parse dates that contain commas", time: "April 22, 2008" do
          expect(subject.observed_on).not_to be(nil)
        end

        it "should NOT parse a date like '2004'", time: "2004" do
          expect(subject).not_to be_valid
        end

        it "should properly parse relative datetimes like '2 days ago'", time: "2 days ago" do
          Time.use_zone(subject.user.time_zone) do
            expect(subject.observed_on).to eq 2.days.ago.to_date
          end
        end

        it "should not save relative dates/times like 'yesterday'", time: "yesterday" do
          expect(subject.observed_on_string.split.include?('yesterday')).to be(false)
        end

        it "should default to the user's time zone" do
          expect(subject.time_zone).to eq subject.user.time_zone
        end

        it "should parse translated AM/PM" do
          I18n.with_locale( :ru ) do
            o = build :observation, observed_on_string: "2022-01-01 11 вечера"
            o.munge_observed_on_with_chronic
            expect( o.time_observed_at_in_zone.hour ).to eq 23
          end
        end

        it "should parse translated AM/PM regardless of case" do
          I18n.with_locale( :ru ) do
            o = build :observation, observed_on_string: "2022-01-01 11 ВЕЧЕРА"
            o.munge_observed_on_with_chronic
            expect( o.time_observed_at_in_zone.hour ).to eq 23
          end
        end
      end

      context "when the user has a time zone" do
        let(:u_est) { build_stubbed :user, time_zone: "Eastern Time (US & Canada)" }
        let(:u_cot) { build_stubbed :user, time_zone: "Bogota" }

        it "should use the user's time zone if the date string only has an offset and it matches the user's time zone" do
          o_est = build_stubbed :observation, :without_times, user: u_est, observed_on_string: "2019-01-29 9:21:46 a. m. GMT-05:00"
          o_est.run_callbacks :validation
          expect( o_est.time_zone ).to eq u_est.time_zone
          o_cot = build_stubbed :observation, :without_times, user: u_cot, observed_on_string: "2019-01-29 9:21:46 a. m. GMT-05:00"
          o_cot.run_callbacks :validation
          expect( o_cot.time_zone ).to eq u_cot.time_zone
        end

        it "should use the user's time zone if the date string only has an offset and it matches the user's time zone during daylight savings time" do
          o_est = build_stubbed :observation, :without_times, user: u_est, observed_on_string: "2018-06-29 9:21:46 a. m. GMT-05:00"
          o_est.run_callbacks :validation
          expect( o_est.time_zone ).to eq u_est.time_zone
          o_cot = build_stubbed :observation, :without_times, user: u_cot, observed_on_string: "2018-06-29 9:21:46 a. m. GMT-05:00"
          o_cot.run_callbacks :validation
          expect( o_cot.time_zone ).to eq u_cot.time_zone
        end

        it "should parse out a time even if a problem time zone code is in the observed_on_string" do
          u_cdt = create :user, time_zone: "Central Time (US & Canada)"
          o_cdt = create :observation, :without_times, user: u_cdt, observed_on_string: "2019-03-24 2:10 PM CDT"

          expect( o_cdt.time_zone ).to eq u_cdt.time_zone
          expect( o_cdt.time_observed_at ).not_to be_blank
        end
      end

      it "should NOT use the user's time zone if another was set" do
        subject.time_zone = 'Eastern Time (US & Canada)'
        subject.run_callbacks :validation

        expect(subject.time_zone).not_to eq subject.user.time_zone
        expect(subject.time_zone).to eq 'Eastern Time (US & Canada)'
      end

      it "should save the time in the time zone selected" do
        subject.time_zone = 'Eastern Time (US & Canada)'
        subject.run_callbacks :validation

        expect(subject.time_observed_at.in_time_zone(subject.time_zone).hour).to eq 12
      end

      it "should not choke of bad dates" do
        observation = create :observation, :without_times
        observation.observed_on_string = "this is not a date"

        expect { observation.save }.not_to raise_error
      end

      it "should not be in the future" do
        expect { create :observation, :without_times, observed_on_string: '2 weeks from now' }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it "should parse a bunch of test date strings" do
        [
            ['Fri Apr 06 2012 16:23:35 GMT-0500 (GMT-05:00)', month: 4, day: 6, hour: 16, offset: '-05:00'],
            ['Sun Nov 03 2013 08:15:25 GMT-0500 (GMT-5)', month: 11, day: 3, hour: 8, offset: '-05:00'],

            # This won't work given our current setup because if we lookup a time
            # zone by offset like this, it will return the first *named* timezone,
            # which in this case is Amsterdam, which is the same as CET, which, in
            # September, observes daylight savings time, so it's actually CEST and
            # the offset is +2:00. The main problem here is that if the client just
            # specifies an offset, we can't reliably find the zone
            # ['September 27, 2012 8:09:50 AM GMT+01:00', :month => 9, :day => 27, :hour => 8, :offset => "+01:00"],

            # This *does* work b/c in December, Amsterdam is in CET, standard time
            ['December 27, 2012 8:09:50 AM GMT+01:00', month: 12, day: 27, hour: 8, offset: '+01:00'],
            # Spacy AM, offset w/o named zone
            ['2019-01-29 9:21:46 a. m. GMT-05:00', month: 1, day: 29, hour: 9, offset: '-05:00'],
            ['Thu Dec 26 2013 11:18:22 GMT+0530 (GMT+05:30)', month: 12, day: 26, hour: 11, offset: '+05:30'],
            ['Thu Feb 20 2020 11:46:32 GMT+1030 (GMT+10:30)', month: 2, day: 20, hour: 11, offset: '+10:30'],
            ['Thu Feb 20 2020 11:46:32 GMT+10:30', month: 2, day: 20, hour: 11, offset: '+10:30'],
            # ['2010-08-23 13:42:55 +0000', :month => 8, :day => 23, :hour => 13, :offset => "+00:00"],
            ['2014-06-18 5:18:17 pm CEST', month: 6, day: 18, hour: 17, offset: '+02:00'],
            ['2017-03-12 12:17:00 pm PDT', month: 3, day: 12, hour: 12, offset: '-07:00'],
            ['2017/03/12 12:17 PM PDT', month: 3, day: 12, hour: 12, offset: '-07:00'],
            ['2017/03/12 12:17 P.M. PDT', month: 3, day: 12, hour: 12, offset: '-07:00'],
            # ["2017/03/12 12:17 AM PDT", month: 3, day: 12, hour: 0, offset: "-07:00"], # this doesn't work.. why...
            ['2017/04/12 12:17 AM PDT', month: 4, day: 12, hour: 0, offset: '-07:00'],
            ['2020/09/02 8:28 PM UTC', month: 9, day: 2, hour: 20, offset: '+00:00'],
            ['2020/09/02 8:28 PM GMT', month: 9, day: 2, hour: 20, offset: '+00:00'],
            ['2021-03-02T13:00:10.000-06:00', month: 3, day: 2, hour: 13, offset: '-06:00'],
            ["Mon Feb 14 2022 09:41:56 GMT-0500 (EST)", month: 2, day: 14, hour: 9, offset: "-05:00"]
        ].each do |date_string, opts|
          observation = build :observation, :without_times, observed_on_string: date_string
          observation.run_callbacks :validation

          expect(observation.observed_on.day).to eq opts[:day]
          expect(observation.observed_on.month).to eq opts[:month]
          time = observation.time_observed_at.in_time_zone(observation.time_zone)
          expect(time.hour).to eq opts[:hour]
          expect(time.formatted_offset).to eq opts[:offset]
        end
      end

      it "should parse Spanish date strings" do
        [
            ['lun nov 04 2013 04:22:34 p.m. GMT-0600 (GMT-6)', month: 11, day: 4, hour: 16, offset: "-06:00"],
            ['lun dic 09 2013 23:37:08 GMT-0800 (GMT-8)', month: 12, day: 9, hour: 23, offset: "-08:00"],
            ['jue dic 12 2013 00:54:02 GMT-0800 (GMT-8)', month: 12, day: 12, hour: 0, offset: "-08:00"]
        ].each do |date_string, opts|
          observation = build :observation, :without_times, observed_on_string: date_string
          observation.run_callbacks :validation

          expect(ActiveSupport::TimeZone[observation.time_zone].formatted_offset).to eq opts[:offset]
          expect(observation.observed_on.month).to eq opts[:month]
          expect(observation.observed_on.day).to eq opts[:day]
          expect(observation.time_observed_at.in_time_zone(observation.time_zone).hour).to eq opts[:hour]
        end
      end

      it "should handle a user without a time zone" do
        observation = build :observation, :without_times, user: build(:user, time_zone: nil),
                                          observed_on_string: "2018-06-29 9:21:46 a. m. GMT-05:00"
        observation.run_callbacks :validation

        expect( observation.observed_on ).not_to be_blank
      end

      it "should set the time zone to UTC if the user's time zone is blank" do
        observation = build :observation, :without_times, observed_on_string: nil, user: build(:user, time_zone: nil)
        observation.run_callbacks :validation

        expect(observation.time_zone).to eq 'UTC'
      end

      it "should set the time zone to PST if the user's time zone is HST and the observed_on_string has PST" do
        usr = create :user, time_zone: "Hawaii"
        obs = build :observation, :without_times, user: usr,
          observed_on_string: "Mon Feb 14 2022 09:41:56 GMT-0800 (PST)"
        obs.run_callbacks :validation
        expect( obs.time_zone ).to eq "Pacific Time (US & Canada)"
      end
    end

    it "should have a matching identification if taxon is known" do
      observation = create :observation

      expect(observation.identifications.empty?).not_to be(true)
      expect(observation.identifications.first.taxon).to eq observation.taxon
    end

    it "should not have an identification if taxon is not known" do
      observation = create :observation, taxon: nil

      expect(observation.identifications.to_a).to be_blank
    end

    it "should not queue a DJ job to refresh lists" do
      Delayed::Job.delete_all
      stamp = Time.now
      Observation.make!(:taxon => Taxon.make!)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /List.*refresh_with_observation/m}).to be_blank
    end

    it "should trim whitespace from species_guess" do
      observation = create :observation, species_guess: " Anna's Hummingbird     "

      expect(observation.species_guess).to eq "Anna's Hummingbird"
    end

    it "should increment the counter cache in users" do
      observation = create :observation
      Delayed::Worker.new.work_off
      observation.reload
      old_count = observation.user.observations_count
      Observation.make!(:user => observation.user)
      Delayed::Worker.new.work_off
      observation.reload
      expect(observation.user.observations_count).to eq old_count+1
    end

    describe "setting lat lon" do
      let(:lat) { 37.91143999 }
      let(:lon) { -122.2687819 }

      it "sets latlon and place guess on save" do
        observation = create :observation

        expect(observation).to receive(:set_latlon_from_place_guess)
        expect(observation).to receive(:set_place_guess_from_latlon)
        observation.save
      end

      it "should allow lots of sigfigs" do
        observation = create :observation, latitude: lat, longitude: lon

        expect(observation.latitude.to_f).to eq lat
        expect(observation.longitude.to_f).to eq lon
      end

      it "should set lat/lon if entered in place_guess" do
        observation = build :observation, latitude: nil, longitude: nil, place_guess: "#{lat}, #{lon}"
        observation.set_latlon_from_place_guess

        expect(observation.latitude.to_f).to eq lat
        expect(observation.longitude.to_f).to eq lon
      end

      it "should set lat/lon if entered in place_guess as NSEW" do
        observation = build :observation, latitude: nil, longitude: nil, place_guess: "S#{lat * -1}, W#{lon * -1}"
        observation.set_latlon_from_place_guess

        expect(observation.latitude.to_f).to eq lat * -1
        expect(observation.longitude.to_f).to eq lon
      end

      it "should not set lat/lon for addresses with numbers" do
        observation = build :observation, place_guess: "Apt 1, 33 Figueroa Ave., Somewhere, CA"
        observation.set_latlon_from_place_guess

        expect(observation.latitude).to be_blank
      end

      it "should not set lat/lon for addresses with zip codes" do
        observation = build :observation, place_guess: "94618"
        observation.set_latlon_from_place_guess

        expect(observation.latitude).to be_blank

        observation2 = build :observation, place_guess: "94618-5555"
        observation.set_latlon_from_place_guess

        expect(observation2.latitude).to be_blank
      end
    end

    describe "place_admin_name" do
      let( :state_place ) do
        make_place_with_geom(
          wkt: "MULTIPOLYGON(((1 1,1 2,2 2,2 1,1 1)))",
          admin_level: Place::STATE_LEVEL,
          name: "State Place"
        )
      end
      let( :county_place ) do
        make_place_with_geom(
          wkt: "MULTIPOLYGON(((1.3 1.3,1.3 1.7,1.7 1.7,1.7 1.3,1.3 1.3)))",
          parent: state_place,
          admin_level: Place::COUNTY_LEVEL,
          name: "County Place"
        )
      end
      it "should return proper place_admin1_name and place_admin2_name" do
        o = Observation.make!( latitude: county_place.latitude, longitude: county_place.longitude )
        expect( o.place_admin1_name ).to eq state_place.name
        expect( o.place_admin2_name ).to eq county_place.name
      end
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
        big_place.update(code: "USA")
        o = Observation.make!(latitude: small_place.latitude, longitude: small_place.longitude)
        expect( o.place_guess ).to match /#{ big_place.code }/
        expect( o.place_guess ).not_to match /#{ big_place.name }/
      end
      it "should use names translated for the observer" do
        big_place.update( name: "Mexico" )
        user = User.make!( locale: "es-MX" )
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude, user: user )
        expect( o.place_guess ).to match /#{ I18n.t( "places_name.mexico", locale: user.locale ) }/
      end
      it "should get changed when coordinates are obscured" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        original_place_guess = o.place_guess
        o.update( geoprivacy: Observation::OBSCURED )
        o.reload
        expect( o.place_guess ).not_to be_blank
        expect( o.place_guess ).not_to eq original_place_guess
      end
      it "should get removed when coordinates are hidden" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        o.update( geoprivacy: Observation::PRIVATE )
        o.reload
        expect( o.place_guess ).to be_blank
      end
      it "should get restored when geoprivacy changes from private to obscured" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude, geoprivacy: Observation::PRIVATE )
        expect( o.place_guess ).to be_blank
        expect( o.latitude ).to be_blank
        o.update( geoprivacy: Observation::OBSCURED )
        o.reload
        expect( o.latitude ).not_to be_blank
        expect( o.place_guess ).not_to be_blank
      end
    end
  
    describe "quality_grade" do
      subject { build_stubbed :observation }

      it "should default to casual" do
        subject.run_callbacks :update

        expect(subject.quality_grade).to eq Observation::CASUAL
      end
    end

    it "should trim to the user_agent to 255 char" do
      observation = create :observation, user_agent: <<-EOT
        Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR
        1.0.3705; .NET CLR 1.1.4322; Media Center PC 4.0; .NET CLR 2.0.50727;
        .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; .NET CLR 3.0.4506.2152;
        .NET CLR 3.5.30729; PeoplePal 7.0; PeoplePal 7.3; .NET4.0C; .NET4.0E;
        OfficeLiveConnector.1.5; OfficeLivePatch.1.3) w:PACBHO60
      EOT

      expect(observation.user_agent.size).to be < 256
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
      p = without_delay { Taxon.make!(rank: Taxon::GENUS) }
      t = without_delay { Taxon.make!(parent: p, rank: Taxon::SPECIES) }
      expect(p.observations_count).to eq 0
      o = without_delay { Observation.make!(:taxon => t) }
      p.reload
      expect(p.observations_count).to eq 1
    end

    it "should be georeferenced? with zero degrees" do
      expect( Observation.make!(longitude: 1, latitude: 1) ).to be_georeferenced
    end

    it "should not be georeferenced with nil degrees" do
      expect( Observation.make!(longitude: 1, latitude: nil) ).not_to be_georeferenced
    end

    it "should be georeferenced? even with private geoprivacy" do
      o = Observation.make!(:latitude => 1, :longitude => 1, :geoprivacy => Observation::PRIVATE)
      expect(o).to be_georeferenced
    end

    it "should create an observation review for the observer if there's a taxon" do
      user = User.make!
      o = Observation.make!( taxon: Taxon.make!, editing_user_id: user.id, user: user )
      o.reload
      expect( o.observation_reviews.where( user_id: o.user_id ).count ).to eq 1
    end

    it "should not create an observation review for the observer if there's no taxon" do
      o = Observation.make!
      o.reload
      expect( o.observation_reviews.where( user_id: o.user_id ).count ).to eq 0
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

    it "should set positional_accuracy to nil if it's zero" do
      o = Observation.make!( latitude: 1, longitude: 1, positional_accuracy: 0 )
      expect( o.positional_accuracy ).to be_nil
    end

    it "should replace an inactive taxon with its active equivalent" do
      taxon_change = make_taxon_swap
      taxon_change.committer = taxon_change.user
      taxon_change.commit
      expect( taxon_change.input_taxon ).not_to be_is_active
      o = Observation.make!( taxon: taxon_change.input_taxon )
      Delayed::Worker.new.work_off
      o.reload
      expect( o.taxon ).to eq taxon_change.output_taxon
    end

    describe "identification category" do
      it "should be set" do
        t = Taxon.make!
        o = Observation.make!( taxon: t )
        Delayed::Job.find_each{|j| j.invoke_job}
        expect( o.identifications.first.taxon ).to eq t
        expect( o.identifications.first.category ).to eq Identification::LEADING
      end
    end

    it "should set time_zone to the Rails time zone even when set to the zic time zone" do
      tz = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      o = Observation.make!( time_zone: tz.tzinfo.name )
      expect( o.time_zone ).to eq tz.name
      expect( o.zic_time_zone ).to eq tz.tzinfo.name
    end

    it "should set zic_time_zone to the zic time zone even when set to the Rails time zone" do
      tz = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
      o = Observation.make!( zic_time_zone: tz.name )
      expect( o.time_zone ).to eq tz.name
      expect( o.zic_time_zone ).to eq tz.tzinfo.name
    end

    it "should set time_zone to a Rails time zone when a zic time zone we know about was specified but Rails ignores it" do
      ignored_time_zones = { "America/Toronto" => "Eastern Time (US & Canada)" }
      ignored_time_zones.each do |tz_name, rails_name|
        o = Observation.make!( time_zone: tz_name )
        expect( o.time_zone ).to eq rails_name
      end
    end

    it "should set time_zone to the zic time zone when a zic time zone we don't know about was specified but Rails ignores it" do
      u = User.make!( time_zone: "Pacific Time (US & Canada)" )
      iana_tz = "America/Bahia"
      expect( ActiveSupport::TimeZone[iana_tz] ).not_to be_nil
      expect( ActiveSupport::TimeZone::MAPPING.invert[iana_tz] ).to be_nil
      o = Observation.make!( user: u, time_zone: "America/Bahia" )
      expect( o.time_zone ).to eq iana_tz
    end

    it "should not allow observed_on to be more than 130 years ago" do
      o = build :observation, observed_on_string: 140.years.ago.to_s
      expect( o ).not_to be_valid
      expect( o.errors[:observed_on] ).not_to be_blank
    end
  end

  describe "updating" do
    it "should not allow observed on to become more than 130 years ago" do
      o = create :observation
      expect( o ).to be_valid
      expect( o.errors[:observed_on] ).to be_blank
      o.update( observed_on_string: 140.years.ago.to_s )
      expect( o ).not_to be_valid
      expect( o.errors[:observed_on] ).not_to be_blank
    end

    it "should allow observed on to remain more than 130 years ago" do
      o = create :observation
      bad_date = 140.years.ago
      Observation.where( id: o.id ).update( observed_on: bad_date.to_date.to_s )
      o.reload
      expect( o ).to be_valid
      expect( o.errors[:observed_on] ).to be_blank
      o.update( description: "#{o.description} and then some" )
      expect( o ).to be_valid
      expect( o.errors[:observed_on] ).to be_blank
    end

    it "should create an obs review if taxon set but was blank and updated by the observer" do
      o = Observation.make!
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 0
      o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      o.reload
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 1
    end

    it "should create an obs review identified by the observer" do
      o = Observation.make!
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 0
      after_delayed_job_finishes { Identification.make!( observation: o, user: o.user )}
      o.reload
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 1
    end

    it "should not create an obs review identified by someone else" do
      o = Observation.make!
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 0
      after_delayed_job_finishes { Identification.make!( observation: o )}
      o.reload
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 0
    end

    it "should not destroy the owner's old identification if the taxon has changed" do
      t1 = Taxon.make!
      t2 = Taxon.make!
      o = Observation.make!(:taxon => t1)
      old_owners_ident = o.identifications.detect{|ident| ident.user_id == o.user_id}
      o.update( taxon: t2, editing_user_id: o.user_id )
      o.reload
      expect(Identification.find_by_id(old_owners_ident.id)).not_to be_blank
    end

    it "should not destroy the owner's old identification if the taxon has changed unless it's the owner's only identification" do
      t1 = Taxon.make!
      o = Observation.make!(:taxon => t1)
      old_owners_ident = o.identifications.detect{|ident| ident.user_id == o.user_id}
      o.update( taxon: nil, editing_user_id: o.user_id )
      o.reload
      expect(Identification.find_by_id(old_owners_ident.id)).to be_blank
    end

    describe "observed_on_string" do
      let(:observation) {
        Observation.make!(
          taxon: Taxon.make!, 
          observed_on_string: "yesterday at 1pm", 
          time_zone: "UTC"
        )
      }
      it "should properly set date and time" do
        observation.observed_on_string = 'March 16 2007 at 2pm'
        observation.save
        expect(observation.observed_on).to eq Date.parse('2007-03-16')
        expect(observation.time_observed_at_in_zone.hour).to eq(14)
      end
      
      it "should not save a time if one wasn't specified" do
        observation.update(:observed_on_string => "April 2 2008")
        observation.save
        expect(observation.time_observed_at).to be_blank
      end
      
      it "should clear date if observed_on_string blank" do
        expect(observation.observed_on).not_to be_blank
        observation.update(:observed_on_string => "")
        expect(observation.observed_on).to be_blank
      end

      it "should not allow dates greater that created_at + 1 day when updated by the observer" do
        o_2_days_ago = Observation.make!( created_at: 2.days.ago, observed_on_string: 3.day.ago.to_s )
        expect( o_2_days_ago ).to be_valid
        o_2_days_ago.update( observed_on_string: Time.now.to_s, editing_user_id: o_2_days_ago.user_id )
        expect( o_2_days_ago ).not_to be_valid
      end

      it "should not allow dates that are greater than created_at due to time zone mismatch" do
        Time.use_zone( "UTC" ) do
          o_2_days_ago = Observation.make!(
            created_at: DateTime.parse( "2019-01-20 23:00" ),
            observed_on_string: "2019-01-19",
            time_zone: "Hong Kong"
          )
          expect( o_2_days_ago ).to be_valid
          new_observed_on_string = "2019-01-20 23:00"
          o_2_days_ago.update( observed_on_string: new_observed_on_string )
          expect( o_2_days_ago ).to be_valid
        end
      end

      it "should not allow dates that are greater than created_at due to chronic's weird time parsing" do
        Time.use_zone "UTC" do
          d = Chronic.parse( "2019-03-04 3pm" )
          observed_on_string = "3 whatever"
          o = Observation.make!( created_at: d, observed_on_string: d.to_s )
          Observation.where( id: o.id ).update_all( observed_on_string: observed_on_string )
          o.reload
          expect( o.observed_on_string ).to eq observed_on_string
          expect( o.created_at.to_date ).to eq d.to_date
          expect( o.observed_on ).to eq d.to_date
          observed_on = o.observed_on
          o.update( updated_at: Time.now )
          o.reload
          expect( o.observed_on.to_s ).to eq observed_on.to_s
        end
      end
    end
  
    it "should set an iconic taxon if the taxon was set" do
      obs = Observation.make!
      expect(obs.iconic_taxon).to be_blank
      taxon = Taxon.make!(:iconic_taxon => Taxon.make!(:is_iconic => true))
      expect(taxon.iconic_taxon).not_to be_blank
      obs.taxon = taxon
      obs.editing_user_id = obs.user_id
      obs.save!
      expect(obs.iconic_taxon.name).to eq taxon.iconic_taxon.name
    end
  
    it "should remove an iconic taxon if the taxon was removed" do
      taxon = Taxon.make!(:iconic_taxon => Taxon.make!(:is_iconic => true))
      expect(taxon.iconic_taxon).not_to be_blank
      obs = Observation.make!(:taxon => taxon)
      expect(obs.iconic_taxon).not_to be_blank
      obs.taxon = nil
      obs.editing_user_id = obs.user_id
      obs.save!
      obs.reload
      expect(obs.iconic_taxon).to be_blank
    end

    it "should not queue refresh jobs for associated project lists if the taxon changed" do
      o = Observation.make!(:taxon => Taxon.make!)
      pu = ProjectUser.make!(:user => o.user)
      po = ProjectObservation.make!(:observation => o, :project => pu.project)
      Delayed::Job.delete_all
      stamp = Time.now
      o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /ProjectList.*refresh_with_observation/m}).to be_blank
    end
  
    it "should queue refresh job for check lists if the coordinates changed" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      o.update(:latitude => o.latitude + 1)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /CheckList.*refresh_with_observation/m}).not_to be_blank
    end

    it "should not queue job to refresh life lists if taxon changed" do
      o = Observation.make!(:taxon => Taxon.make!)
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      end
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /LifeList.*refresh_with_observation/m}.size).to eq(0)
    end

    it "should not queue job to refresh project lists if taxon changed" do
      po = make_project_observation(:taxon => Taxon.make!)
      o = po.observation
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      end
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /ProjectList.*refresh_with_observation/m}.size).to eq(0)
    end

    it "should only queue one check list refresh job" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update(:latitude => o.latitude + 1)
      end
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /CheckList.*refresh_with_observation/m}.size).to eq(1)
    end
  
    it "should queue refresh job for check lists if the taxon changed" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      o = Observation.find(o.id)
      o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      pattern = /CheckList.*refresh_with_observation/m
      job = jobs.detect{|j| j.handler =~ pattern}
      expect(job).not_to be_blank
      # puts job.handler.inspect
    end
  
    it "should not queue refresh job for project lists if the taxon changed" do
      po = make_project_observation
      o = po.observation
      Delayed::Job.delete_all
      stamp = Time.now
      o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      pattern = /ProjectList.*refresh_with_observation/m
      job = jobs.detect{|j| j.handler =~ pattern}
      expect(job).to be_blank
      # puts job.handler.inspect
    end
  
    it "should not allow impossible coordinates" do
      o = Observation.make!
      o.update(:latitude => 100)
      expect(o).not_to be_valid
    
      o = Observation.make!
      o.update(:longitude => 200)
      expect(o).not_to be_valid
    
      o = Observation.make!
      o.update(:latitude => -100)
      expect(o).not_to be_valid
    
      o = Observation.make!
      o.update(:longitude => -200)
      expect(o).not_to be_valid
    end

    it "should add the taxon to a check list for an enclosing place if the quality became research" do
      t = Taxon.make!(:species)
      p = without_delay { make_place_with_geom }
      o = without_delay { make_research_grade_candidate_observation( latitude: p.latitude, longitude: p.longitude, taxon: t ) }
      expect( p.check_list.taxa ).not_to include t
      i = without_delay { Identification.make!( observation: o, taxon: t ) }
      o.reload
      expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      p.reload
      expect( p.check_list.taxa ).to include t
    end
  
    describe "quality_grade" do
      it "should become research when it qualifies" do
        o = Observation.make!(:taxon => Taxon.make!(rank: 'species'), latitude: 1, longitude: 1)
        i = Identification.make!(:observation => o, :taxon => o.taxon)
        o.photos << LocalPhoto.make!(:user => o.user)
        o.reload
        expect(o.quality_grade).to eq Observation::CASUAL
        o.update(:observed_on_string => "yesterday")
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
        o.update( taxon: new_taxon, editing_user_id: o.user_id )
        expect(o.quality_grade).to eq Observation::NEEDS_ID
      end
    
      it "should become casual when date removed" do
        o = make_research_grade_observation
        expect(o.quality_grade).to eq Observation::RESEARCH_GRADE
        o.update(:observed_on_string => "")
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

      it "should be casual if the community taxon is Homo" do
        t = Taxon.make!( name: "Homo", rank: Taxon::GENUS )
        o = Observation.make!( taxon: t )
        i = Identification.make!( observation: o, taxon: t )
        expect( o.community_taxon ).to eq t
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual if the taxon is Homo" do
        t = Taxon.make!( name: "Homo", rank: Taxon::GENUS )
        o = make_research_grade_candidate_observation( taxon: t )
        expect( o.community_taxon ).to be_blank
        expect( o.taxon ).to eq t
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
        Observation.set_quality_grade(o.id)
        o.reload
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      it "should be research grade if the taxon is in a different subtree from the CID taxon" do
        owner_taxon = Taxon.make!( rank: Taxon::SPECIES )
        community_taxon = Taxon.make!( rank: Taxon::SPECIES )
        o = make_research_grade_candidate_observation( taxon: owner_taxon )
        3.times { Identification.make!( observation: o, taxon: community_taxon ) }
        o.reload
        expect( o.community_taxon ).to eq community_taxon
        expect( o.owners_identification.taxon ).to eq owner_taxon
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be needs_id when voted out of needs_id if no CID" do
        o = make_research_grade_candidate_observation( taxon: Taxon.make!(:species) )
        o.downvote_from User.make!, vote_scope: "needs_id"
        expect( o.identifications.count ).to eq 1
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      describe "when observer opts out of CID" do
        let(:u) { User.make!( prefers_community_taxa: false ) }
        it "should be casual if the taxon is in a different subtree from the CID taxon" do
          species1 = Taxon.make!( rank: Taxon::SPECIES )
          species2 = Taxon.make!( rank: Taxon::SPECIES )
          o = make_research_grade_candidate_observation( taxon: species1, user: u )
          3.times { Identification.make!( observation: o, taxon: species2 ) }
          o.reload
          expect( o.community_taxon ).to eq species2
          expect( o.taxon ).to eq species1
          expect( o.quality_grade ).to eq Observation::CASUAL
        end
        it "should be needs_id if no CID" do
          o = make_research_grade_candidate_observation( user: u )
          expect( o.community_taxon ).to be_blank
          expect( o.quality_grade ).to eq Observation::NEEDS_ID
        end
        it "should be needs_id if the taxon matches the CID taxon and the CID taxon is a family" do
          family = Taxon.make!( rank: Taxon::FAMILY )
          o = make_research_grade_candidate_observation( taxon: family, user: u )
          Identification.make!( observation: o, taxon: family )
          o.reload
          expect( o.community_taxon ).to eq family
          expect( o.taxon ).to eq family
          expect( o.quality_grade ).to eq Observation::NEEDS_ID
        end
        it "should be needs_id if the taxon is above species and is an ancestor of the CID taxon" do
          genus = Taxon.make!( rank: Taxon::GENUS )
          species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
          o = make_research_grade_candidate_observation( taxon: genus, user: u )
          3.times { Identification.make!( observation: o, taxon: species ) }
          o.reload
          expect( o.community_taxon ).to eq species
          expect( o.taxon ).to eq genus
          expect( o.quality_grade ).to eq Observation::NEEDS_ID
        end
        describe "if the taxon is a genus and the CID is the same genus" do
          let(:genus) { Taxon.make!( rank: Taxon::GENUS ) }
          let(:o) { make_research_grade_candidate_observation( taxon: genus, user: u ) }
          before do
            3.times { Identification.make!( observation: o, taxon: genus ) }
            o.reload
            expect( o.community_taxon ).to eq genus
            expect( o.taxon ).to eq genus
          end
          it "should be needs_id if it hasn't been voted out of needs_id" do
            expect( o.quality_grade ).to eq Observation::NEEDS_ID
          end
          it "should be research if it has been voted out of needs_id" do
            o.downvote_from User.make!, vote_scope: "needs_id"
            o.reload
            expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
          end
        end
        it "should be needs_id if the CID taxon is an ancestor of the taxon" do
          genus = Taxon.make!( rank: Taxon::GENUS )
          species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
          o = make_research_grade_candidate_observation( taxon: species, user: u )
          3.times { Identification.make!( observation: o, taxon: genus ) }
          o.reload
          expect( o.community_taxon ).to eq genus
          expect( o.taxon ).to eq species
          expect( o.quality_grade ).to eq Observation::NEEDS_ID
        end
        it "should be research if the taxon matches the CID taxon and the CID taxon is a species" do
          species = Taxon.make!( rank: Taxon::SPECIES )
          o = make_research_grade_candidate_observation( taxon: species, user: u )
          Identification.make!( observation: o, taxon: species )
          o.reload
          expect( o.community_taxon ).to eq species
          expect( o.taxon ).to eq species
          expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        end
        it "should be research if the taxon is a species that contains the CID taxon" do
          species = Taxon.make!( rank: Taxon::SPECIES )
          subspecies = Taxon.make!( rank: Taxon::SUBSPECIES, parent: species )
          o = make_research_grade_candidate_observation( taxon: species, user: u )
          2.times { Identification.make!( observation: o, taxon: subspecies ) }
          o.reload
          expect( o.community_taxon ).to eq subspecies
          expect( o.taxon ).to eq species
          expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        end
        it "should be research if the taxon and CID taxon are both the same subspecies" do
          species = Taxon.make!( rank: Taxon::SPECIES )
          subspecies = Taxon.make!( rank: Taxon::SUBSPECIES, parent: species )
          o = make_research_grade_candidate_observation( taxon: subspecies, user: u )
          Identification.make!( observation: o, taxon: subspecies )
          o.reload
          expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        end
        it "should be casual if the observer has no ID and the CID is at species" do
          o = make_research_grade_candidate_observation( prefers_community_taxon: false )
          species = Taxon.make!( rank: Taxon::SPECIES )
          2.times { Identification.make!( observation: o, taxon: species ) }
          o.reload
          expect( o.owners_identification ).to be_blank
          expect( o.community_taxon ).to eq species
          expect( o.taxon ).to be_blank
          expect( o.quality_grade ).to eq Observation::CASUAL
        end
        it "should be casual if there are conservative disagreements with the observer and the community votes it out of needs_id" do
          genus = Taxon.make!( rank: Taxon::GENUS )
          species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
          o = make_research_grade_candidate_observation( prefers_community_taxon: false, taxon: species )
          2.times{ Identification.make!( observation: o, taxon: genus ) }
          o.reload
          expect( o.quality_grade ).to eq Observation::NEEDS_ID
          o.downvote_from User.make!, vote_scope: "needs_id"
          o.reload
          expect( o.quality_grade ).to eq Observation::CASUAL
        end
        it "should be research if the taxon matches the CID taxon and the CID taxon is a subgenus and voted out of needs_id" do
          subgenus = Taxon.make!( name: "Pyrobombus", rank: Taxon::SUBGENUS )
          o = make_research_grade_candidate_observation( taxon: subgenus, user: u )
          Identification.make!( observation: o, taxon: subgenus )
          o.reload
          o.downvote_from User.make!, vote_scope: "needs_id"
          o.reload
          expect( o.community_taxon ).to eq subgenus
          expect( o.taxon ).to eq subgenus
          expect( o ).to be_voted_out_of_needs_id
          expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        end
        it "should be research if the taxon matches the CID taxon and the CID taxon is a subfamily and voted out of needs_id" do
          subfamily = Taxon.make!( name: "Hydropsychinae", rank: Taxon::SUBFAMILY )
          o = make_research_grade_candidate_observation( taxon: subfamily, user: u )
          Identification.make!( observation: o, taxon: subfamily )
          o.reload
          o.downvote_from User.make!, vote_scope: "needs_id"
          o.reload
          expect( o.community_taxon ).to eq subfamily
          expect( o.taxon ).to eq subfamily
          expect( o ).to be_voted_out_of_needs_id
          expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        end
      end

      describe "when observer opts out of CID for a single observation" do
        it "should be casual if the taxon is in a different subtree from the CID taxon" do
          species1 = Taxon.make!( rank: Taxon::SPECIES )
          species2 = Taxon.make!( rank: Taxon::SPECIES )
          o = make_research_grade_candidate_observation( taxon: species1, prefers_community_taxon: false )
          3.times { Identification.make!( observation: o, taxon: species2 ) }
          o.reload
          expect( o.community_taxon ).to eq species2
          expect( o.taxon ).to eq species1
          expect( o.quality_grade ).to eq Observation::CASUAL
        end
      end
    end
  
    it "should queue a job to update user lists"
    it "should queue a job to update check lists"

    describe "obscuring for conservation status" do
      let(:place) { make_place_with_geom }
      let(:species) { create :taxon, :as_species }
      it "should obscure coordinates if taxon has a conservation status in the place observed" do
        cs = create :conservation_status, place: place, taxon: species
        o = create :observation, latitude: place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).to be_coordinates_obscured
      end

      it "should not obscure coordinates if taxon has a conservation status in another place" do
        cs = create :conservation_status, place: place, taxon: species
        o = create :observation, latitude: -1*place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).not_to be_coordinates_obscured
      end

      it "should obscure coordinates if locally threatened but globally secure" do
        local_cs = create :conservation_status, place: place, taxon: species
        global_cs = create :conservation_status,
          taxon: species,
          status: "LC",
          iucn: Taxon::IUCN_LEAST_CONCERN,
          geoprivacy: Observation::OPEN
        o = create :observation, latitude: place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).to be_coordinates_obscured
      end

      it "should not obscure coordinates if secure in state but globally threatened" do
        place.update( admin_level: Place::STATE_LEVEL )
        local_cs = create :conservation_status,
          place: place,
          taxon: species,
          status: "LC",
          iucn: Taxon::IUCN_LEAST_CONCERN,
          geoprivacy: Observation::OPEN
        global_cs = create :conservation_status, taxon: species
        o = create :observation, latitude: place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).not_to be_coordinates_obscured
      end

      it "should obscure coordinates if secure in state and globally threatened and another suggested taxon is globally threatened" do
        place.update( admin_level: Place::STATE_LEVEL )
        local_cs1 = create :conservation_status,
          place: place,
          taxon: species,
          status: "LC",
          iucn: Taxon::IUCN_LEAST_CONCERN,
          geoprivacy: Observation::OPEN
        global_cs1 = create :conservation_status, taxon: species
        global_cs2 = create :conservation_status
        o = create :observation, latitude: place.latitude, longitude: place.longitude, taxon: species
        expect( o ).not_to be_coordinates_obscured
        create :identification, observation: o, taxon: global_cs2.taxon
        expect( o ).to be_coordinates_obscured
      end

      it "should obscure coordinates if secure in state and globally threatened and another suggested taxon is threatened in an overlapping state" do
        place1 = make_place_with_geom( admin_level: Place::STATE_LEVEL )
        place2 = make_place_with_geom( admin_level: Place::STATE_LEVEL )
        local_cs1 = create :conservation_status,
          place: place1,
          taxon: species,
          status: "LC",
          iucn: Taxon::IUCN_LEAST_CONCERN,
          geoprivacy: Observation::OPEN
        local_cs2 = create :conservation_status,
          place: place2,
          status: "EN",
          iucn: Taxon::IUCN_ENDANGERED,
          geoprivacy: Observation::OBSCURED
        global_cs = create :conservation_status, taxon: species
        o = create :observation, latitude: place.latitude, longitude: place.longitude, taxon: species
        expect( o ).not_to be_coordinates_obscured
        create :identification, observation: o, taxon: local_cs2.taxon
        expect( o ).to be_coordinates_obscured
      end

      it "should not obscure coordinates if conservation statuses exist but all are open" do
        cs = create :conservation_status, place: place, taxon: species, geoprivacy: Observation::OPEN
        cs_global = create :conservation_status, taxon: species, geoprivacy: Observation::OPEN
        o = create :observation, latitude: -1*place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).not_to be_coordinates_obscured
      end

      describe "when at least one ID is of a threatened taxon" do
        let(:o) { make_research_grade_observation( latitude: place.latitude, longitude: place.longitude ) }
        it "should obscure coordinates if taxon has a conservation status in the place observed" do
          expect( o ).not_to be_coordinates_obscured
          create :conservation_status, place: place, taxon: species
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).to be_coordinates_obscured
        end
        it "should not obscure coordinates if taxon has a conservation status in another place" do
          o.update( latitude: ( place.latitude * -1 ), longitude: ( place.longitude * -1 ) )
          expect( o ).not_to be_coordinates_obscured
          create :conservation_status, place: place, taxon: species
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).not_to be_coordinates_obscured
        end
        it "should obscure coordinates if locally threatened but globally secure" do
          expect( o ).not_to be_coordinates_obscured
          global_cs = create :conservation_status,
            taxon: species,
            iucn: Taxon::IUCN_LEAST_CONCERN,
            geoprivacy: Observation::OPEN
          local_cs = create :conservation_status, place: place, taxon: species
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).to be_coordinates_obscured
        end
        it "should not obscure coordinates if secure in state but globally threatened" do
          expect( o ).not_to be_coordinates_obscured
          place.update( admin_level: Place::STATE_LEVEL )
          local_cs = create :conservation_status,
            place: place,
            taxon: species,
            iucn: Taxon::IUCN_LEAST_CONCERN,
            geoprivacy: Observation::OPEN
          global_cs = create :conservation_status, taxon: species
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).not_to be_coordinates_obscured
        end
        it "should not obscure coordinates if conservation statuses exist but all are open" do
          expect( o ).not_to be_coordinates_obscured
          global_cs = create :conservation_status, taxon: species, geoprivacy: Observation::OPEN
          local_cs = create :conservation_status, place: place, taxon: species, geoprivacy: Observation::OPEN
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).not_to be_coordinates_obscured
        end
      end

      describe "when a dissenting ID is of a non-threatened taxon" do
        before { load_test_taxa }
        let(:cs) { create :conservation_status, taxon: @Calypte_anna }
        let(:o) { create :observation, taxon: cs.taxon, latitude: 1, longitude: 1 }
        before do
          expect( o.community_taxon ).to be_blank
          create :identification, observation: o, taxon: o.taxon
          o.reload
          expect( o.community_taxon ).to eq cs.taxon
          expect( o ).to be_coordinates_obscured
        end
        it "should not reveal the coordinates" do
          i2 = create :identification, observation: o, taxon: @Pseudacris_regilla
          o.reload
          expect( o.community_taxon ).not_to eq cs.taxon
          expect( o ).to be_coordinates_obscured
        end
        it "should reveal the coordinates if the dissenting ID is not current" do
          i2 = create :identification, observation: o, taxon: @Pseudacris_regilla
          i3 = create :identification, observation: o, taxon: @Calypte_anna, user: i2.user
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
      o.update( taxon: t, editing_user_id: o.user_id )
      Delayed::Job.find_each{|j| j.invoke_job}
      t.reload
      expect(t.observations_count).to eq(1)
    end
  
    it "should increment the taxon's ancestors' counter caches" do
      o = Observation.make!
      p = without_delay { Taxon.make!(rank: Taxon::GENUS) }
      t = without_delay { Taxon.make!(parent: p, rank: Taxon::SPECIES) }
      expect(p.observations_count).to eq 0
      o.update( taxon: t, editing_user_id: o.user_id )
      Delayed::Job.find_each{|j| j.invoke_job}
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
      o = without_delay {o.update( taxon: nil, editing_user_id: o.user_id )}
      t.reload
      expect(t.observations_count).to eq(0)
    end
  
    it "should decrement the taxon's ancestors' counter caches" do
      p = Taxon.make!(rank: Taxon::GENUS)
      t = Taxon.make!(parent: p, rank: Taxon::SPECIES)
      o = without_delay {Observation.make!(:taxon => t)}
      p.reload
      expect(p.observations_count).to eq(1)
      o = without_delay {o.update( taxon: nil, editing_user_id: o.user_id )}
      p.reload
      expect(p.observations_count).to eq(0)
    end

    it "should not update a listed taxon stats" do
      t = Taxon.make!
      u = User.make!
      l = List.make!(user: u)
      lt = ListedTaxon.make!(list: l, taxon: t)
      expect(lt.first_observation).to be_blank
      o1 = without_delay { Observation.make!(taxon: t, user: u, observed_on_string: '2014-03-01') }
      o2 = without_delay { Observation.make!(taxon: t, user: u, observed_on_string: '2015-03-01') }
      lt.reload
      expect(lt.first_observation).to  be_blank
      expect(lt.last_observation).to  be_blank
    end
  end

  describe "destruction" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "should decrement the counter cache in users" do
      @observation = Observation.make!
      Delayed::Worker.new.work_off
      user = @observation.user
      user.reload
      old_count = user.observations_count
      @observation.destroy
      Delayed::Worker.new.work_off
      user.reload
      expect(user.observations_count).to eq old_count - 1
    end
  
    it "should not queue a DJ job to refresh lists" do
      Delayed::Job.delete_all
      stamp = Time.now
      Observation.make!(:taxon => Taxon.make!)
      jobs = Delayed::Job.where("created_at >= ?", stamp)
      expect(jobs.select{|j| j.handler =~ /List.*refresh_with_observation/m}).to be_blank
    end

    it "should delete associated updates" do
      subscriber = User.make!
      user = User.make!
      s = Subscription.make!(:user => subscriber, :resource => user)
      o = Observation.make(:user => user)
      without_delay { o.save! }
      expect( UpdateAction.unviewed_by_user_from_query(subscriber.id, resource: user) ).to eq true
      o.destroy
      expect( UpdateAction.unviewed_by_user_from_query(subscriber.id, resource: user) ).to eq false
    end

    it "should delete associated project observations" do
      po = make_project_observation
      o = po.observation
      o.destroy
      expect(ProjectObservation.find_by_id(po.id)).to be_blank
    end

    it "should decrement the taxon's counter cache" do
      t = Taxon.make!
      o = without_delay{ Observation.make!( taxon: t) }
      t.reload
      expect( t.observations_count ).to eq 1
      o.destroy
      Delayed::Job.find_each{|j| j.invoke_job}
      t.reload
      expect( t.observations_count ).to eq 0
    end
  
    it "should decrement the taxon's ancestors' counter caches" do
      p = Taxon.make!(rank: Taxon::GENUS)
      t = Taxon.make!(parent: p, rank: Taxon::SPECIES)
      o = without_delay {Observation.make!(:taxon => t)}
      p.reload
      expect(p.observations_count).to eq(1)
      o.destroy
      Delayed::Job.find_each{|j| j.invoke_job}
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

    it "should create a deleted photo" do
      o = make_research_grade_observation
      p = o.photos.first
      without_delay { o.destroy }
      expect( Photo.find_by_id( p.id ) ).to be_blank
      expect( DeletedPhoto.where( photo_id: p.id ).count ).to eq 1
    end
    it "should create a deleted sound" do
      o = Observation.make!
      s = Sound.make!
      o.sounds << s
      without_delay { o.destroy }
      expect( Sound.find_by_id( s.id ) ).to be_blank
      expect( DeletedSound.where( sound_id: s.id ).count ).to eq 1
    end
  end

  describe "species_guess parsing" do
    stub_elastic_index! Observation, Taxon

    let(:user) { build :user }
    let(:observation) { build :observation, taxon: nil, user: user, editing_user_id: user.id }

    it "should choose a taxon if the guess corresponds to a unique taxon" do
      taxon = create :taxon, :as_species
      observation.species_guess = taxon.name
      observation.set_taxon_from_species_guess
      expect( observation.taxon_id ).to eq taxon.id
    end

    it "should choose a taxon from species_guess if exact matches form a subtree" do
      taxon = create :taxon, :as_species, name: "Spirolobicus bananaensis"
      child = create :taxon, :as_subspecies, parent: taxon, name: "#{taxon.name} foo"
      common_name = "Spiraled Banana Shrew"
      create :taxon_name, taxon: taxon, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: child, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]

      observation.species_guess = common_name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to eq taxon.id
    end

    it "should not choose a taxon from species_guess if exact matches don't form a subtree" do
      ancestor1 = create :taxon, :as_genus
      ancestor2 = create :taxon, :as_genus
      taxon = create :taxon, :as_species, parent: ancestor1, name: "Spirolobicus bananaensis"
      child = create :taxon, :as_subspecies, parent: taxon, name: "#{taxon.name} foo"
      taxon2 = create :taxon, :as_species, parent: ancestor2
      common_name = "Spiraled Banana Shrew"
      create :taxon_name, taxon: taxon, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: child, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: taxon2, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]
      expect(child.ancestors).to include(taxon)
      expect(child.ancestors).not_to include(taxon2)
      expect(Taxon.joins(:taxon_names).where("taxon_names.name = ?", common_name).count).to eq(3)

      observation.species_guess = common_name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to be_blank
    end

    it "should choose a taxon from species_guess if exact matches form a subtree regardless of case" do
      taxon = create :taxon, rank: "species", name: "Spirolobicus bananaensis"
      child = create :taxon, rank: "subspecies", parent: taxon, name: "#{taxon.name} foo"
      common_name = "Spiraled Banana Shrew"
      create :taxon_name, taxon: taxon, name: common_name.downcase, lexicon: TaxonName::LEXICONS[:ENGLISH]
      create :taxon_name, taxon: child, name: common_name, lexicon: TaxonName::LEXICONS[:ENGLISH]

      observation.species_guess = common_name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to eq taxon.id
    end
  
    it "should not make a guess for problematic names" do
      Taxon::PROBLEM_NAMES.each do |name|
        next unless build(:taxon, name: name.capitalize).valid?

        observation = build :observation, species_guess: name
        expect { observation.set_taxon_from_species_guess }.to_not change { observation.taxon_id }
      end
    end
  
    it "should choose a taxon from a parenthesized scientific name" do
      name = "Northern Pygmy Owl (Glaucidium gnoma)"
      t = create :taxon, name: "Glaucidium gnoma"

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to eq t.id
    end
  
    it "should choose a taxon from blah sp" do
      name = "Clarkia sp"
      t = create :taxon, name: "Clarkia"

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to eq t.id
    
      name = "Clarkia sp."

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to eq t.id
    end
  
    it "should choose a taxon from blah ssp" do
      name = "Clarkia ssp"
      t = create :taxon, name: "Clarkia"

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to eq t.id
    
      name = "Clarkia ssp."

      observation.species_guess = name
      observation.set_taxon_from_species_guess
      expect(observation.taxon_id).to eq t.id
    end

    it "should not make a guess if ends in a question mark" do
      t = create :taxon, name: "Foo bar"

      observation.species_guess = "#{t.name}?"
      observation.set_taxon_from_species_guess
      expect(observation.taxon).to be_blank
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
      pos = make_research_grade_candidate_observation
      expect( pos.quality_grade ).to eq Observation::NEEDS_ID
      observations = Observation.has_id_please
      expect( observations ).to include( pos )
      expect( observations ).not_to include( @neg )
    end
    
    describe "has_photos" do
      it "should find observations with photos" do
        make_observation_photo(:observation => @pos)
        obs = Observation.has_photos.all
        expect(obs).to include(@pos)
        expect(obs).not_to include(@neg)
      end
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
        t = without_delay { Taxon.make!(rank: Taxon::GENUS) }
        c = without_delay { Taxon.make!(parent: t, rank: Taxon::SPECIES) }
        o = Observation.make!(:taxon => c)
        expect(Observation.of(t).first).to eq o
      end
    end

    describe :with_identifications_of do
      it "should include observations with identifications of the taxon" do
        i = Identification.make!
        o = Observation.make!
        expect( Observation.with_identifications_of( i.taxon ) ).to include i.observation
        expect( Observation.with_identifications_of( i.taxon ) ).not_to include o
      end
      it "should include observations with identifications of descendant taxa" do
        parent = Taxon.make!( rank: Taxon::GENUS )
        child = Taxon.make!( rank: Taxon::SPECIES, parent: parent )
        i = Identification.make!( taxon: child )
        expect( Observation.with_identifications_of( parent ) ).to include i.observation
      end
      it "should not return duplicate observations when there are multiple identifications" do
        o = Observation.make!
        i1 = Identification.make!( observation: o )
        i2 = Identification.make!( observation: o, taxon: i1.taxon )
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
      parent = cs.taxon
      parent.update( rank: Taxon::SPECIES, rank_level: Taxon::SPECIES_LEVEL )
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
      observation.update( taxon: Taxon.make!, editing_user_id: observation.user_id )
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
        observation.update( taxon: cs.taxon, editing_user_id: observation.user_id )
        expect( observation.place_guess.to_s ).to eq ""
      end
    end
  
    it "should not be included in json" do
      observation = Observation.make!( defaults )
      expect( observation.to_json ).not_to match( /#{observation.private_latitude}/ )
      expect( observation.to_json ).not_to match( /#{observation.private_place_guess}/ )
    end
  
    it "should not be included in a json array" do
      observation = Observation.make!( defaults )
      Observation.make!
      observations = Observation.paginate( page: 1, per_page: 2 ).order( id: :desc )
      expect( observations.to_json ).not_to match( /#{observation.private_latitude}/ )
      expect( observation.to_json ).not_to match( /#{observation.private_place_guess}/ )
    end

    it "should not be included in by_login_all csv generated for others" do
      observation = Observation.make!( defaults )
      Observation.make!
      path = Observation.generate_csv_for( observation.user )
      txt = File.open( path ).read
      expect( txt ).not_to match( /private_latitude/ )
      expect( txt ).not_to match( /#{observation.private_latitude}/ )
      expect( observation.to_json ).not_to match( /#{observation.private_place_guess}/ )
    end

    it "should be visible to curators of projects to which the observation has been added" do
      po = make_project_observation
      expect( po.project_user.preferred_curator_coordinate_access ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER
      expect( po ).to be_prefers_curator_coordinate_access
      o = po.observation
      o.update( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1 )
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::CURATOR )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be true
    end

    it "should be visible to managers of projects to which the observation has been added" do
      po = make_project_observation
      o = po.observation
      o.update( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1 )
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::MANAGER )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be true
    end

    it "should not be visible to managers of projects to which the observation has been added if the observer is not a member" do
      po = ProjectObservation.make!
      expect( po.observation.user.project_ids ).not_to include po.project_id
      o = po.observation
      o.update( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1 )
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::MANAGER )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be false
    end

    it "should be visible to managers of projects if observer allows it for this observation" do
      po = ProjectObservation.make!( prefers_curator_coordinate_access: true )
      expect( po.observation.user.project_ids ).not_to include po.project_id
      o = po.observation
      o.update( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1)
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

    describe "curator_coordinate_access_for" do
      let(:place) { make_place_with_geom }
      let(:project) do
        proj = Project.make(:collection)
        proj.update( prefers_user_trust: true )
        pu = ProjectUser.make!(
          project: proj,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
        )
        proj.project_observation_rules << ProjectObservationRule.new( operator: "observed_in_place?", operand: place )
        proj.reload
        proj
      end
      let(:non_curator) do
        u = ProjectUser.make!( project: project ).user
        u.reload
        u
      end
      let(:curator) do
        u = ProjectUser.make!( project: project, role: ProjectUser::CURATOR ).user
        u.reload
        u
      end
      def stub_api_response_for_observation( o )
        response_json = <<-JSON
          {
            "results": [
              {
                "id": #{o.id},
                "non_traditional_projects": [
                  {
                    "project": {
                      "id": #{project.id}
                    }
                  }
                ]
              }
            ]
          }
        JSON
        stub_request(:get, /#{INatAPIService::ENDPOINT}/).to_return(
          status: 200,
          body: response_json,
          headers: { "Content-Type" => "application/json" }
        )
      end
      let(:o) do
        Observation.make!( latitude: place.latitude, longitude: place.longitude, taxon: make_threatened_taxon )
      end
      it "should not allow curator access by default" do
        pu = ProjectUser.make!( project: project, user: o.user )
        stub_api_response_for_observation( o )
        expect( o ).to be_in_collection_projects( [project] )
        expect( o ).to be_coordinates_obscured
        expect( o.coordinates_viewable_by?( curator ) ).to be false
      end
      it "should not allow curator access if the project observation requirements changed during the wait period" do
        expect( project.observation_requirements_updated_at ).to be > ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
        pu = ProjectUser.make!(
          project: project,
          user: o.user,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
        )
        stub_api_response_for_observation( o )
        expect( o ).to be_in_collection_projects( [project] )
        expect( o ).to be_coordinates_obscured
        expect( o.coordinates_viewable_by?( curator ) ).to be false
      end
      it "should allow curator access if the project observation requirements changed beofre the wait period" do
        allow_any_instance_of( Project ).to receive(:observation_requirements_updated_at).
          and_return( ( ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD + 1.week ).ago )
        expect( project.observation_requirements_updated_at ).to be < ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
        pu = ProjectUser.make!(
          project: project,
          user: o.user,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
        )
        stub_api_response_for_observation( o )
        expect( o ).to be_in_collection_projects( [project] )
        expect( o ).to be_coordinates_obscured
        expect( o.coordinates_viewable_by?( curator ) ).to be true
      end
      describe "taxon" do
        let(:pu) do
          ProjectUser.make!(
            project: project,
            user: o.user,
            prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_TAXON
          )
        end
        before do
          allow_any_instance_of( Project ).to receive(:observation_requirements_updated_at).
            and_return( ( ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD + 1.week ).ago )
          expect( project.observation_requirements_updated_at ).to be < ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
          expect( pu.preferred_curator_coordinate_access_for ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_TAXON
        end
        it "should allow curator access to coordinates of a threatened taxon" do
          stub_api_response_for_observation( o )
          expect( o ).to be_in_collection_projects( [project] )
          expect( o ).to be_coordinates_obscured
          expect( o.coordinates_viewable_by?( curator ) ).to be true
        end
        it "should not allow non-curator access to coordinates of a threatened taxon" do
          stub_api_response_for_observation( o )
          expect( o ).to be_in_collection_projects( [project] )
          expect( o ).to be_coordinates_obscured
          expect( o.coordinates_viewable_by?( non_curator ) ).to be false
        end
        it "should not allow curator access to coordinates of a threatened taxon if geoprivacy is obscured" do
          o.update( geoprivacy: Observation::OBSCURED )
          stub_api_response_for_observation( o )
          expect( o ).to be_in_collection_projects( [project] )
          expect( o ).to be_coordinates_obscured
          expect( o.coordinates_viewable_by?( curator ) ).to be false
        end
      end
      describe "any" do
        let(:pu) do
          ProjectUser.make!(
            project: project,
            user: o.user,
            prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
          )
        end
        before do
          allow_any_instance_of( Project ).to receive(:observation_requirements_updated_at).
            and_return( ( ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD + 1.week ).ago )
          expect( project.observation_requirements_updated_at ).to be < ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
          expect( pu.preferred_curator_coordinate_access_for ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
        end
        it "should not allow curator access if disabled" do
          project.update( prefers_user_trust: false )
          stub_api_response_for_observation( o )
          expect( o ).to be_in_collection_projects( [project] )
          expect( o ).to be_coordinates_obscured
          expect( o.coordinates_viewable_by?( curator ) ).to be false
        end
        it "should allow curator access to coordinates of a threatened taxon" do
          stub_api_response_for_observation( o )
          expect( o ).to be_in_collection_projects( [project] )
          expect( o ).to be_coordinates_obscured
          expect( o.coordinates_viewable_by?( curator ) ).to be true
        end
        it "should allow curator access to coordinates of a threatened taxon if geoprivacy is obscured" do
          o.update( geoprivacy: Observation::OBSCURED )
          stub_api_response_for_observation( o )
          expect( o ).to be_in_collection_projects( [project] )
          expect( o ).to be_coordinates_obscured
          expect( o.coordinates_viewable_by?( curator ) ).to be true
        end
      end
    end
  end
  
  describe "obscure_coordinates" do
    stub_elastic_index! Observation

    it "should not affect observations without coordinates" do
      o = build_stubbed :observation
      expect(o.latitude).to be_blank
      o.obscure_coordinates
      expect(o.latitude).to be_blank
      expect(o.private_latitude).to be_blank
      expect(o.longitude).to be_blank
      expect(o.private_longitude).to be_blank
    end
  
    it "should not affect already obscured coordinates" do
      o = create :observation, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED
      lat = o.latitude
      private_lat = o.private_latitude
      expect(o).to be_coordinates_obscured
      o.obscure_coordinates
      o.reload
      expect(o.latitude.to_f).to eq lat.to_f
      expect(o.private_latitude.to_f).to eq private_lat.to_f
    end
  
    it "should not affect already obscured coordinates of a protected taxon" do
      o = create :observation, latitude: 1, longitude: 1, taxon: create(:taxon, :threatened)
      lat = o.latitude
      private_lat = o.private_latitude
      expect(o).to be_coordinates_obscured
      o.geoprivacy = Observation::OBSCURED
      o.obscure_coordinates
      expect(o.latitude.to_f).to eq lat.to_f
      expect(o.private_latitude.to_f).to eq private_lat.to_f
    end
  
  end

  describe "unobscure_coordinates" do
    stub_elastic_index! Observation

    it "should work" do
      true_lat = 38.0
      true_lon = -122.0
      o = create :observation, latitude: true_lat, longitude: true_lon, taxon: create(:taxon, :threatened)
      expect(o).to be_coordinates_obscured
      expect(o.latitude.to_f).not_to eq true_lat
      expect(o.longitude.to_f).not_to eq true_lon
      o.unobscure_coordinates
      expect(o).not_to be_coordinates_obscured
      expect(o.latitude.to_f).to eq true_lat
      expect(o.longitude.to_f).to eq true_lon
    end
  
    it "should not affect observations without coordinates" do
      o = build_stubbed :observation
      expect(o.latitude).to be_blank
      o.unobscure_coordinates
      expect(o.latitude).to be_blank
      expect(o.private_latitude).to be_blank
      expect(o.longitude).to be_blank
      expect(o.private_longitude).to be_blank
    end
  
    it "should not unobscure observations with obscured geoprivacy" do
      o = create :observation, latitude: 38, longitude: -122, geoprivacy: Observation::OBSCURED
      o.unobscure_coordinates
      expect(o).to be_coordinates_obscured
    end
  
    it "should not unobscure observations with private geoprivacy" do
      o = create :observation, latitude: 38, longitude: -122, geoprivacy: Observation::PRIVATE
      o.unobscure_coordinates
      expect(o).to be_coordinates_obscured
      expect(o.latitude).to be_blank
    end

    it "should reset public_positional_accuracy" do
      o = create :observation, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED, positional_accuracy: 5
      expect(o.public_positional_accuracy).not_to eq o.positional_accuracy
      # unobscure_coordinates should be impossible if geoprivacy gets set
      o.geoprivacy = nil
      o.unobscure_coordinates
      # public_positional_accuracy only gets reset after saving
      o.save
      expect(o.public_positional_accuracy).to eq o.positional_accuracy
    end

  end

  describe "geoprivacy" do
    stub_elastic_index! Observation

    let(:geoprivacy) { Observation::PRIVATE }
    let(:latitude) { 37 }
    let(:longitude) { -122 }
    let(:taxon) { build :taxon }

    subject do
      create :observation,
             taxon: taxon,
             latitude: latitude,
             longitude: longitude,
             geoprivacy: geoprivacy,
             place_guess: "Duluth, MN"
    end

    context "when geoprivacy private" do
      it { is_expected.to be_coordinates_obscured}

      it "should remove public coordinates" do
        expect(subject.latitude).to be_blank
        expect(subject.longitude).to be_blank
      end

      it "should remove place_guess" do
        expect(subject.place_guess).to be_blank
      end

      it "should remove public coordinates if coords change but not geoprivacy" do
        subject.update latitude: 1, longitude: 1

        expect(subject).to be_coordinates_obscured
        expect(subject.latitude).to be_blank
        expect(subject.longitude).to be_blank
      end

      it "should restore public coordinates when removing geoprivacy" do
        expect(subject.latitude).to be_blank
        expect(subject.longitude).to be_blank
        subject.update geoprivacy: nil
        expect(subject.latitude.to_f).to eq latitude
        expect(subject.longitude.to_f).to eq longitude
      end
    end

    context "when geoprivacy obscured" do
      let(:geoprivacy) { Observation::OBSCURED }
      let(:threatened_taxon) { create :taxon, :threatened }

      it { is_expected.to be_coordinates_obscured}

      it "should remove public coordinates when moving to private" do
        expect(subject.latitude).not_to be_blank
        expect(subject.longitude).not_to be_blank
        subject.update geoprivacy: Observation::PRIVATE
        expect(subject.latitude).to be_blank
        expect(subject.longitude).to be_blank
      end

      context "with threatened taxon" do
        let(:taxon) { create :taxon, :threatened }

        it "should not unobscure observations of threatened taxa" do
          expect(subject).to be_coordinates_obscured
          subject.update geoprivacy: nil
          expect(subject.geoprivacy).to be_blank
          expect(subject).to be_coordinates_obscured
        end
      end
    end

    context "when geoprivacy not obscured or private" do
      let(:geoprivacy) { "open" }

      it "should be nil " do
        expect(subject.geoprivacy).to be_nil
      end

      it "should remove place_guess from to_plain_s when geoprivacy updated" do
        original_place_guess = subject.place_guess
        expect(subject.to_plain_s).to match /#{original_place_guess}/
        subject.update geoprivacy: Observation::OBSCURED
        expect(subject.to_plain_s).not_to match /#{original_place_guess}/
        expect(subject.private_place_guess).not_to be_blank
      end

      context "with threatened taxon" do
        let(:taxon) { create :taxon, :threatened }

        it "should remove public coordinates when made private" do
          expect(subject).to be_coordinates_obscured
          expect(subject.latitude).not_to be_blank
          subject.update geoprivacy: Observation::PRIVATE
          expect(subject.latitude).to be_blank
          expect(subject.longitude).to be_blank
        end
      end
    end

    it "should set public coordinates to something other than the private coordinates when going from private to obscured" do
      o = create :observation, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED
      Delayed::Worker.new.work_off
      o.reload
      expect( o.private_latitude ).not_to eq o.latitude
      o.update( geoprivacy: Observation::PRIVATE )
      Delayed::Worker.new.work_off
      o.reload
      expect( o.private_latitude ).not_to eq o.latitude
      o.update( geoprivacy: Observation::OBSCURED )
      Delayed::Worker.new.work_off
      o.reload
      expect( o.private_latitude ).not_to eq o.latitude
    end
  end

  describe "#set_geom_from_latlon" do
    let!(:observation) { create :observation }

    before { allow(observation).to receive(:set_geom_from_latlon) }

    it "gets called on save" do
      observation.run_callbacks :save

      expect(observation).to have_received :set_geom_from_latlon
    end
  end

  describe "geom" do
    let(:observation) { build :observation, latitude: latitude, longitude: longitude }
    let(:latitude) { 1 }
    let(:longitude) { 1 }

    before { observation.set_geom_from_latlon }

    context "with coords" do
      it "should be set" do
        expect(observation.geom).not_to be_blank
      end

      it "should change" do
        expect(observation.geom.y).to eq 1.0
        observation.latitude = 2
        observation.set_geom_from_latlon
        expect(observation.geom.y).to eq 2.0
      end

      it "should go away" do
        expect(observation.geom).to_not be_blank
        observation.assign_attributes latitude: nil, longitude: nil
        observation.set_geom_from_latlon
        expect(observation.geom).to be_blank
      end
    end

    context "without coords" do
      let(:latitude) { nil }
      let(:longitude) { nil }

      it "should not be set" do
        expect(observation.geom).to be_blank
      end
    end
  end

  describe "private_geom" do
    let(:observation) { build :observation, latitude: latitude, longitude: longitude, geoprivacy: geoprivacy }
    let(:geoprivacy) { nil }
    let(:latitude) { 1 }
    let(:longitude) { 1 }

    before { observation.set_geom_from_latlon }

    context "with coords" do
      it "should be set" do
        expect(observation.private_geom).not_to be_blank
      end

      it "should change" do
        expect(observation.private_geom.y).to eq 1.0
        observation.assign_attributes latitude: 2
        observation.set_geom_from_latlon
        expect(observation.private_geom.y).to eq 2.0
      end

      it "should go away" do
        expect(observation.private_geom).not_to be_blank
        observation.assign_attributes latitude: nil, longitude: nil
        observation.set_geom_from_latlon
        expect(observation.private_geom).to be_blank
      end

      context "and with geoprivacy" do
        let(:geoprivacy) { Observation::OBSCURED }

        prepend_before { observation.reassess_coordinate_obscuration }

        it "should be set" do
          expect(observation.latitude).not_to eq 1.0
          expect(observation.private_latitude).to eq 1.0
          expect(observation.geom.y).not_to eq 1.0
          expect(observation.private_geom.y).to eq 1.0
        end
      end

      context "and without geoprivacy" do
        it "should be set" do
          expect(observation.latitude).to eq 1.0
          expect(observation.private_geom.y).to eq 1.0
        end
      end
    end

    context "without coords" do
      let(:latitude) { nil }
      let(:longitude) { nil }

      it "should not be set" do
        expect(observation.private_geom).to be_blank
      end
    end
  end

  describe "query" do
    it "should filter by quality_grade" do
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
      o1 = Observation.make!( taxon: @Aves )
      o2 = Observation.make!( taxon: @Amphibia )
      o3 = Observation.make!( taxon: @Animalia )
      expect( @Aves ).to be_is_iconic
      expect( @Amphibia ).to be_is_iconic
      expect( @Animalia ).to be_is_iconic
      observations = Observation.query( taxon_ids: [@Aves.id, @Amphibia.id] ).to_a
      expect( observations ).to include( o1 )
      expect( observations ).to include( o2 )
      expect( observations ).not_to include( o3 )
    end
  end

  describe "to_json" do
    it "should not include script tags" do
      o = build_stubbed :observation, description: "<script lang='javascript'>window.close()</script>"
      expect(o.to_json).not_to match(/<script/)
      expect(o.to_json(viewer: o.user,
        force_coordinate_visibility: true,
        include: [:user, :taxon, :iconic_taxon])).not_to match(/<script/)
      o = build_stubbed :observation, species_guess: "<script lang='javascript'>window.close()</script>"
      expect(o.to_json).not_to match(/<script/)
    end
  end

  describe "#set_license" do
    let!(:observation) { create :observation }

    before { allow(observation).to receive(:set_license) }

    it "sets geom on save" do
      observation.run_callbacks :save

      expect(observation).to have_received :set_license
    end
  end

  describe "license" do
    stub_elastic_index! Observation

    it "should use the user's default observation license" do
      o = build_stubbed :observation,
                        license: nil,
                        user: build_stubbed(:user, preferred_observation_license: "CC-BY-NC")
      o.set_license
      expect(o.license).to eq o.user.preferred_observation_license
    end

    it "should nilify if not a license" do
      o = build_stubbed :observation, license: Observation::CC_BY
      o.set_license
      expect(o.license).to_not be_blank
      o.assign_attributes license: "on"
      o.set_license
      expect(o.license).to be_blank
    end

    it "should normalize license" do
      o = build_stubbed :observation, license: "cc by Nc"
      o.set_license
      expect(o.license).to eq Observation::CC_BY_NC
    end

    it "should update default license when requested" do
      u = create :user
      expect(u.preferred_observation_license).to be_blank
      o = create :observation, user: u, make_license_default: true, license: Observation::CC_BY_NC
      expect( o.license ).to eq Observation::CC_BY_NC
      u.reload
      expect(u.preferred_observation_license).to eq Observation::CC_BY_NC
    end

    it "should update all other observations when requested" do
      u = create :user
      o1 = create :observation, user: u, license: nil
      o2 = create :observation, user: u, license: nil
      expect(o1.license).to be_blank
      o2.make_licenses_same = true
      o2.license = Observation::CC_BY_NC
      o2.save
      o1.reload
      expect(o1.license).to eq Observation::CC_BY_NC
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
      p = make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 1,1 1,1 0,0 0)))", admin_level: Place::STATE_LEVEL )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude, taxon: make_threatened_taxon )
      expect( o.public_places ).to include p
    end
    it "should include system places that don't contain public_positional_accuracy circle" do
      p = make_place_with_geom( wkt: "MULTIPOLYGON(((0 0,0 0.1,0.1 0.1,0.1 0,0 0)))", admin_level: Place::STATE_LEVEL )
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude, taxon: make_threatened_taxon )
      expect( o.public_places ).to include p
    end
    it "should be blank if taxon has conservation status with private geoprivacy" do
      p = make_place_with_geom( admin_level: Place::STATE_LEVEL )
      cs = ConservationStatus.make!( geoprivacy: Observation::PRIVATE )
      o = make_research_grade_candidate_observation( taxon: cs.taxon, latitude: p.latitude, longitude: p.longitude )
      expect( o ).to be_georeferenced
      expect( o.geoprivacy ).to be_blank
      expect( o.public_places ).to be_blank
    end
  end

  describe "corners" do
    describe "when obscured" do
      let(:o) { Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED ) }
      let(:uncertainty_cell_center_latlon) { Observation.uncertainty_cell_center_latlon( o.latitude, o.longitude ) }
      let(:half_cell) { Observation::COORDINATE_UNCERTAINTY_CELL_SIZE / 2 }
      let(:uncertainty_cell_ne_latlon) { uncertainty_cell_center_latlon.map{|c| (c + half_cell).to_f } }
      let(:uncertainty_cell_sw_latlon) { uncertainty_cell_center_latlon.map{|c| (c - half_cell).to_f } }
      it "should match the obscuration cell corners when positional_accuracy is blank" do
        expect( o.positional_accuracy ).to be_blank
        expect( o.ne_latlon.map(&:to_f) ).to eq uncertainty_cell_ne_latlon
        expect( o.sw_latlon.map(&:to_f) ).to eq uncertainty_cell_sw_latlon
      end
      it "should match the positional_accuracy bounding box corners when positional_accuracy is greater than the obscuration cell" do
        o.update( positional_accuracy: 100000 )
        o.reload
        positional_accuracy_degrees = o.positional_accuracy.to_i / (2*Math::PI*Observation::PLANETARY_RADIUS) * 360.0
        positional_accuracy_ne_latlon = [
          o.latitude + positional_accuracy_degrees,
          o.longitude + positional_accuracy_degrees
        ].map(&:to_f)
        positional_accuracy_sw_latlon = [
          o.latitude - positional_accuracy_degrees,
          o.longitude - positional_accuracy_degrees
        ].map(&:to_f)
        expect( o.ne_latlon.map(&:to_f) ).to eq positional_accuracy_ne_latlon
        # expect( o.sw_latlon.map(&:to_f) ).to eq positional_accuracy_sw_latlon
      end
    end
  end

  describe "update_stats" do
    it "should not consider outdated identifications as agreements" do
      o = Observation.make!( taxon: Taxon.make!( rank: "species", name: "Species one" ) )
      old_ident = Identification.make!( observation: o, taxon: o.taxon )
      new_ident = Identification.make!( observation: o, user: old_ident.user, taxon: Taxon.make!( rank: "species", name: "Species two" ) )
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
    elastic_models( Identification )

    it "should work" do
      parent = Taxon.make!(rank: Taxon::GENUS)
      child = Taxon.make!(rank: Taxon::SPECIES)
      o = Observation.make!(:taxon => parent)
      i1 = Identification.make!(:observation => o, :taxon => child)
      o.reload
      expect(o.num_identification_agreements).to eq(0)
      expect(o.num_identification_disagreements).to eq(1)
      child.update(:parent => parent)
      Observation.update_stats_for_observations_of(parent)
      o.reload
      expect(o.num_identification_agreements).to eq(1)
      expect(o.num_identification_disagreements).to eq(0)
    end

    it "should work" do
      parent = Taxon.make!( rank: Taxon::GENUS )
      child = Taxon.make!( rank: Taxon::SPECIES )
      o = Observation.make!( taxon: parent )
      i1 = Identification.make!( observation: o, taxon: child )
      o.reload
      expect( o.community_taxon ).to be_blank
      child.update( parent: parent )
      Observation.update_stats_for_observations_of( parent )
      o.reload
      expect( o.community_taxon ).not_to be_blank
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
      expect { o.update(attrs) }.not_to raise_error
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
      expect { o.update(attrs) }.not_to raise_error
      o.reload
      expect(o.observation_field_values).to be_blank
    end
  end

  describe "taxon updates" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "should generate an update" do
      t = Taxon.make!
      s = Subscription.make!(:resource => t)
      o = Observation.make(:taxon => t)
      expect( UpdateAction.unviewed_by_user_from_query(s.user_id, resource: t) ).to eq false
      without_delay do
        o.save!
      end
      expect( UpdateAction.unviewed_by_user_from_query(s.user_id, resource: t) ).to eq true
    end

    it "should generate an update for descendent taxa" do
      t1 = Taxon.make!(rank: Taxon::GENUS)
      t2 = Taxon.make!(parent: t1, rank: Taxon::SPECIES)
      s = Subscription.make!(:resource => t1)
      o = Observation.make(:taxon => t2)
      expect( UpdateAction.unviewed_by_user_from_query(s.user_id, resource: t1) ).to eq false
      without_delay do
        o.save!
      end
      expect( UpdateAction.unviewed_by_user_from_query(s.user_id, resource: t1) ).to eq true
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
    #     o.update( taxon: t, editing_user_id: o.user_id )
    #   end
    #   u = Update.last
    #   u.should_not be_blank
    #   u.notifier.should eq(o)
    #   u.subscriber.should eq(s.user)
    # end
  end

  describe "place updates" do
    before { enable_has_subscribers }
    after { disable_has_subscribers }

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
        expect( UpdateAction.unviewed_by_user_from_query(@subscription.user_id, notifier: o) ).to eq true
      end
      it "should not generate for observations outside of that place" do
        o = without_delay do
          Observation.make!(:latitude => -1 * @christchurch_lat, :longitude => @christchurch_lon)
        end
        expect( UpdateAction.unviewed_by_user_from_query(@subscription.user_id, notifier: o) ).to eq false
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
      Observation.update_for_taxon_change( @taxon_swap )
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
      expect( o ).not_to be_coordinates_obscured
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
      Delayed::Worker.new.work_off
      o.reload
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
      Observation.reassess_coordinates_for_observations_of( t )
      o.reload
      expect( o.place_guess ).not_to be =~ /#{place_guess}/
      expect( o.place_guess ).to be =~ /#{p.name}/
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
      o.update(:captive_flag => "0")
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
      op = make_observation_photo(:observation => reject)
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
        reject.update( taxon: t, editing_user_id: reject.user_id )
        keeper.update( taxon: t, editing_user_id: keeper.user_id )
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
      o.update(:prefers_community_taxon => true)
      o.reload
      expect(o.community_taxon).to eq(i1.taxon)
    end

    it "should not be unset when preference set to false" do
      o = Observation.make!
      i1 = Identification.make!(:observation => o)
      i2 = Identification.make!(:observation => o, :taxon => i1.taxon)
      o.reload
      expect(o.community_taxon).to eq(i1.taxon)
      o.update(:prefers_community_taxon => false)
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

    it "should not set the taxon if there are no identifications and the user chose a taxon" do
      t = Taxon.make!
      o = Observation.make( taxon: t )
      expect( o.identifications.size ).to eq 0
      expect( o.taxon ).to eq t
      o.save!
      o.reload
      expect( o.taxon ).to eq t
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
      o.update(:prefers_community_taxon => false)
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
      o.update(:prefers_community_taxon => false)
      o.reload
      expect(o.species_guess).to eq owner_taxon.name
    end

    it "should set the taxon if observation is opted in but user is opted out" do
      u = User.make!( prefers_community_taxa: false )
      o = Observation.make!( prefers_community_taxon: true, user: u )
      i1 = Identification.make!( observation: o, taxon: Taxon.make!(:species) )
      i2 = Identification.make!( observation: o, taxon: i1.taxon )
      o.reload
      expect( o.taxon ).to eq o.community_taxon
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
      o.update( taxon: @Plantae, editing_user_id: o.user_id )
      expect(o.community_taxon).not_to be_blank
      expect(o.identifications.count).to eq 2
    end

    it "change should be triggered by activating a taxon" do
      load_test_taxa
      o = Observation.make!
      i1 = Identification.make!( observation: o, taxon: @Pseudacris_regilla )
      i2 = Identification.make!( observation: o, taxon: @Pseudacris_regilla )
      expect( o.community_taxon ).not_to be_blank
      t = Taxon.make!( parent: @Hylidae, rank: "genus", is_active: false )
      expect( t.is_active ).to be( false )
      @Pseudacris_regilla.update( is_active: false )
      expect( @Pseudacris_regilla.is_active ).to be( false )
      @Pseudacris_regilla.parent = t
      @Pseudacris_regilla.save
      expect( @Pseudacris_regilla.parent ).to eq( t )
      Delayed::Worker.new.work_off
      o = Observation.find( o.id )
      expect( o.community_taxon ).to be_blank
      @Pseudacris_regilla.parent = @Pseudacris
      @Pseudacris_regilla.save
      Delayed::Worker.new.work_off
      @Pseudacris_regilla.update( is_active: true )
      Delayed::Worker.new.work_off
      o = Observation.find( o.id )
      expect( o.community_taxon ).not_to be_blank
    end

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

    it "should not consider identifications of inactive taxa" do
      g1 = Taxon.make!( rank: Taxon::GENUS, name: "Genusone" )
      s1 = Taxon.make!( rank: Taxon::SPECIES, parent: g1, name: "Genus speciesone" )
      s2 = Taxon.make!( rank: Taxon::SPECIES, parent: g1, name: "Genus speciestwo", is_active: false )
      o = Observation.make!
      Identification.make!( observation: o, taxon: s1 )
      Identification.make!( observation: o, taxon: s1 )
      Identification.make!( observation: o, taxon: s2 )
      o.reload
      expect( o.community_taxon ).to eq s1
    end

    describe "test cases: " do
      before { setup_test_case_taxonomy }

      it "s1 s1 s2" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        i = Identification.make!(:observation => @o, :taxon => @s2)
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1 )
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 g1.disagreement_nil" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        i = Identification.make!( observation: @o, taxon: @g1 )
        i.update_attribute( :disagreement, nil )
        i.reload
        expect( i.disagreement ).to eq nil
        @o.reload
        @o.set_community_taxon( force: true )
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 g1.disagreement" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: true )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 g1.disagreement_false" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 s1 g1" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @g1)
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 s2 s2" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s2)
        Identification.make!(:observation => @o, :taxon => @s2)
        @o.reload
        expect( @o.community_taxon ).to eq @g1
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
        expect( @o.community_taxon ).to eq @s2
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
        expect( @o.community_taxon ).to eq @g1
      end

      it "f g1 s1 (should not taxa with only one ID to be the community taxon)" do
        Identification.make!(:observation => @o, :taxon => @f)
        Identification.make!(:observation => @o, :taxon => @g1)
        Identification.make!(:observation => @o, :taxon => @s1)
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "f f g1 s1" do
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @f )
        Identification.make!( observation: @o, taxon: @g1 )
        Identification.make!( observation: @o, taxon: @s1 )
        @o.reload
        expect( @o.community_taxon ).to eq @g1
      end

      it "s1 s1 f f" do
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @s1)
        Identification.make!(:observation => @o, :taxon => @f)
        Identification.make!(:observation => @o, :taxon => @f)
        @o.reload
        expect( @o.community_taxon ).to eq @s1
      end

      it "s1 s1 f.disagreement f" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @f, disagreement: true )
        Identification.make!( observation: @o, taxon: @f)
        @o.reload
        expect( @o.community_taxon ).to eq @f
      end
    end
  end

  describe "probable_taxon" do
    describe "test cases: " do
      before { setup_test_case_taxonomy }
      it "s1 should be s1" do
        i = Identification.make!( observation: @o, taxon: @s1 )
        @o.reload
        o = Observation.find( @o.id )
        expect( o.probable_taxon ).to eq @s1
      end
      it "s1 g1.disagreement_true should be g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: true )
        @o.reload
        expect( @o.probable_taxon ).to eq @g1
      end
      it "s1 g1.disagreement_nil should be g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        i = Identification.make!( observation: @o, taxon: @g1 )
        i.update_attribute( :disagreement, nil )
        o = Observation.find( @o.id )
        expect( o.probable_taxon ).to eq @g1
      end
      it "s1 g1.disagreement_false should be s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @s1
      end
      it "ss1 s1.disagreement_false should be ss1" do
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s1, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @ss1
      end
      it "s1 g1.disagreement_false g1.disagreement_false should be s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @s1
      end
      it "s1 g1.disagreement_false should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @g1, disagreement: false )
        @o.reload
        expect( @o.taxon ).to eq @s1
      end
      it "s1 s2 should be g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        @o.reload
        expect( @o.probable_taxon ).to eq @g1
      end
      it "s1 s2 should set taxon to g1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s2 )
        @o.reload
        expect( @o.taxon ).to eq @g1
      end
      it "g2 s1 should set taxon to f" do
        Identification.make!( observation: @o, taxon: @g2 )
        Identification.make!( observation: @o, taxon: @s1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @f
      end
      it "s1 ss1 should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "s1 s1 ss1 should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "ss1 s1.disagreement_false should set the taxon to ss1" do
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s1, disagreement: false )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @ss1
      end
      it "ss1 s1.disagreement_true should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @ss1 )
        Identification.make!( observation: @o, taxon: @s1, disagreement: true )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "s1 ss1 should set the taxon to s1" do
        Identification.make!( observation: @o, taxon: @s1 )
        Identification.make!( observation: @o, taxon: @ss1 )
        o = Observation.find( @o.id )
        expect( o.taxon ).to eq @s1
      end
      it "s1.disagreement_false s2.disagreement_false s2.disagreement_false should be g1" do
        @taxon_swap1 = TaxonSwap.make
        @taxon_swap1.add_input_taxon(@s3)
        @taxon_swap1.add_output_taxon(@s1)
        @taxon_swap1.save!
        @taxon_swap2 = TaxonSwap.make
        @taxon_swap2.add_input_taxon(@s4)
        @taxon_swap2.add_output_taxon(@s2)
        @taxon_swap2.save!

        Identification.make!( observation: @o, taxon: @s3)
        Identification.make!( observation: @o, taxon: @s4)
        @o.reload
        expect(@o.identifications.size).to eq(2)
        expect(@o.identifications.detect{|i| i.taxon_id == @s3.id}).not_to be_blank
        
        @user = make_user_with_role(:admin, created_at: Time.now)
        @taxon_swap1.committer = @user
        @taxon_swap2.committer = @user
        @taxon_swap1.commit
        Delayed::Worker.new.work_off
        @taxon_swap2.commit
        Delayed::Worker.new.work_off
        @s4.reload
        expect(@s4.is_active).to be false
        @o.reload
        expect(@o.identifications.size).to eq(4)
        expect(@o.identifications.detect{|i| i.taxon_id == @s3.id}).not_to be_blank
        
        Identification.make!( observation: @o, taxon: @s2, disagreement: false )
        @o.reload
        expect( @o.probable_taxon ).to eq @g1
      end
      it "g2 f.disagreement_true s1" do
        i1 = Identification.make!( observation: @o, taxon: @g2 )
        i2 = Identification.make!( observation: @o, taxon: @f, disagreement: true )
        i3 = Identification.make!( observation: @o, taxon: @s1, user: i1.user )
        expect( @o.probable_taxon ).to eq @s1
      end
    end
  end

  describe "fields_addable_by?" do
    let(:observer) { build_stubbed :user }
    let(:observation) { build_stubbed :observation, user: observer }
    let(:field_adder) { build_stubbed :user }

    subject { observation.fields_addable_by? field_adder }

    context "for anyone else" do
      it { is_expected.to be true }

      context "no editing preferred" do
        let(:observer_preference) { User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER }
        let(:observer) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be false }
      end
    end

    context "for nil user" do
      let(:field_adder) { nil }

      it { is_expected.to be false }
    end

    context "for curator" do
      let(:field_adder) { build_stubbed :curator }

      it { is_expected.to be true }

      context "and curators preferred" do
        let(:observer_preference) { User::PREFERRED_OBSERVATION_FIELDS_BY_CURATORS }
        let(:observer) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be true }
      end

      context "and no editing preferred" do
        let(:observer_preference) { User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER }
        let(:observer) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be false}
      end
    end

    context "for observer" do
      let(:field_adder) { observer }

      context "and no editing preferred" do
        let(:observer_preference) { User::PREFERRED_OBSERVATION_FIELDS_BY_OBSERVER }
        let(:observer) { build_stubbed :user, preferred_observation_fields_by: observer_preference }

        it { is_expected.to be true}
      end
    end
  end

  describe "mappable" do
    stub_elastic_index! Observation, Taxon

    describe "on save" do
      let!(:observation) { create :observation }

      it "updates mappable" do
        allow(observation).to receive(:update_mappable)
        observation.run_callbacks :save
        expect(observation).to have_received :update_mappable
      end

      it "calculates mappable" do
        allow(observation).to receive(:calculate_mappable)
        observation.run_callbacks :save
        expect(observation).to have_received :calculate_mappable
      end
    end

    describe "#calculate_mappable" do
      let(:observation) { build_stubbed :observation, latitude: lat, longitude: lon }
      let(:lat) { 1.1 }
      let(:lon) { 2.2 }

      context "without lat/lon" do
        let(:lat) { nil }
        let(:lon) { nil }

        it { expect(observation.calculate_mappable).to be false }
      end

      context "with lat/lon" do
        it { expect(observation.calculate_mappable).to be true }

        it "should not be mappable with a terrible accuracy" do
          observation.assign_attributes(public_positional_accuracy: observation.uncertainty_cell_diagonal_meters + 1)
          expect(observation.calculate_mappable).to be false
        end
      end

      context "when adding captive metric" do
        let(:observation) do
          build_stubbed :observation,
                        :with_quality_metric, metric: QualityMetric::WILD,
                        latitude: lat, longitude: lon
        end

        it "should be mappable" do
          expect(observation.calculate_mappable).to be true
        end
      end

      context "with an inaccurate location" do
        let(:observation) do
          build_stubbed :observation,
                        :with_quality_metric, metric: QualityMetric::LOCATION,
                        latitude: lat, longitude: lon
        end

        it { expect(observation.calculate_mappable).to be false }

        it "should be mappable when location metric is deleted" do
          expect(observation.calculate_mappable).to be false
          observation.quality_metrics.reset
          expect(observation.calculate_mappable).to be true
        end
      end

      context "when captive" do
        let(:observation) { build_stubbed :observation, latitude: lat, longitude: lon, captive: true }

        it { expect(observation.calculate_mappable).to be true }
      end

      context "when obscured" do
        let(:observation) { build_stubbed :observation, :research_grade, geoprivacy: Observation::OBSCURED }

        it { expect(observation.calculate_mappable).to be true }
      end

      context "when threatened taxa" do
        let(:threatened_taxon) { build_stubbed :taxon, :threatened }
        let(:observation) { build_stubbed :observation, latitude: lat, longitude: lon, taxon: threatened_taxon }

        it { expect(observation.calculate_mappable).to be true }
      end

      context "when it's not evidence of an organism" do
        let(:observation) do
          build_stubbed :observation, :research_grade, :with_quality_metric, metric: QualityMetric::EVIDENCE
        end

        it { expect(observation.calculate_mappable).to be false }
      end

      context "when it's flagged" do
        let(:observation) { build_stubbed :observation, :research_grade, :with_flag, flag: Flag::SPAM }

        it { expect(observation.calculate_mappable).to be false }
      end
    end

    describe "with a photo" do
      it "should not be mappable if its photo is flagged" do
        o = create :observation, :research_grade
        expect(o.mappable?).to be true
        create :flag, flaggable: o.observation_photos.first.photo, flag: Flag::SPAM
        o.reload
        expect(o.mappable?).to be false
      end
    end

    it "should not be mappable if community disagrees with taxon" do
      t = create :taxon, :as_species
      u = create :user, prefers_community_taxa: false
      o = create :observation, :research_grade, user: u
      5.times { create :identification, observation: o, taxon: t }
      o.reload
      expect(o.taxon).not_to eq t
      expect(o.community_taxon).to eq t
      expect(o.mappable?).to be false
    end

    it "should be mappable if the community taxon contains the taxon" do
      genus = create :taxon, :as_genus
      species = create :taxon, :as_species, parent: genus
      o = make_research_grade_candidate_observation(taxon: genus)
      i = create :identification,  observation: o, taxon: species
      expect(o.taxon).to eq species
      expect(o.community_taxon).to eq genus
      expect(o).to be_mappable
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
      p = Observation.make!(user: u, latitude: 1, longitude: 1, observed_on_string: "2014-06-02 00:00", positional_accuracy: 100)
      n = Observation.make!(user: u, latitude: 2, longitude: 2, observed_on_string: "2014-06-02 02:00", positional_accuracy: 100)
      o = Observation.make!(user: u, observed_on_string: "2014-06-02 01:00")
      o.interpolate_coordinates
      expect( o.latitude ).to eq 1.5
      expect( o.longitude ).to eq 1.5
    end

    it "should use weight by time" do
      u = User.make!
      p = Observation.make!(user: u, latitude: 1, longitude: 1, observed_on_string: "2014-06-02 00:00", positional_accuracy: 100)
      n = Observation.make!(user: u, latitude: 2, longitude: 2, observed_on_string: "2014-06-02 02:00", positional_accuracy: 100)
      o = Observation.make!(user: u, observed_on_string: "2014-06-02 01:59")
      o.interpolate_coordinates
      expect( o.latitude.to_f ).to be > 1.5
      expect( o.longitude.to_f ).to be > 1.5
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
    before { enable_has_subscribers }
    after { disable_has_subscribers }

    it "knows what users have been mentioned" do
      u = User.make!
      o = Observation.make!(description: "hey @#{ u.login }")
      expect( o.mentioned_users ).to eq [ u ]
    end

    it "generates mention updates" do
      u = User.make!
      o = after_delayed_job_finishes( ignore_run_at: true ) { Observation.make!(description: "hey @#{ u.login }") }
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: o) ).to eq true
    end

    it "does not generation a mention update if the description was updated and the mentioned user wasn't in the new content" do
      u = User.make!
      o = without_delay { Observation.make!(description: "hey @#{ u.login }") }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq true
      # mark the generated updates as viewed
      UpdateAction.user_viewed_updates( UpdateAction.where( notifier: o ), u.id )
      after_delayed_job_finishes do
        o.update( description: "#{o.description} and some extra" )
      end
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: o) ).to eq false
    end
    it "removes mention updates if the description was updated to remove the mentioned user" do
      u = User.make!
      o = without_delay { Observation.make!(description: "hey @#{ u.login }") }
      expect( UpdateAction.unviewed_by_user_from_query( u.id, notifier: o ) ).to eq true
      after_delayed_job_finishes( ignore_run_at: true ) { o.update( description: "bye" ) }
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: o) ).to eq false
    end
    it "generates a mention update if the description was updated and the mentioned user was in the new content" do
      u = User.make!
      o = without_delay { Observation.make!(description: "hey") }
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: o) ).to eq false
      after_delayed_job_finishes( ignore_run_at: true ) do
        o.update( description: "#{o.description} @#{u.login}" )
      end
      expect( UpdateAction.unviewed_by_user_from_query(u.id, notifier: o) ).to eq true
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
      @dupe.update(geoprivacy: Observation::OBSCURED)
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).to be_blank
    end
    it "should not assume null datetimes are the same" do
      @obs.update(observed_on_string: nil)
      @dupe.update(observed_on_string: nil)
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
    it "should not assume blank datetimes are the same" do
      @obs.update(observed_on_string: '')
      @dupe.update(observed_on_string: '')
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
    it "should not assume null coordinates are the same" do
      @obs.update(latitude: nil, longitude: nil)
      @dupe.update(latitude: nil, longitude: nil)
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
    it "should not assume null taxa are the same" do
      @obs.update( taxon: nil, editing_user_id: @obs.user_id )
      @dupe.update( taxon: nil, editing_user_id: @dupe.user_id )
      Observation.dedupe_for_user(@obs.user)
      expect( Observation.find_by_id(@obs.id) ).not_to be_blank
      expect( Observation.find_by_id(@dupe.id) ).not_to be_blank
    end
  end

  describe "public_positional_accuracy" do
    it "should be set on read if nil" do
      t = make_threatened_taxon
      o = make_research_grade_observation( taxon: t )
      expect( o ).to be_coordinates_obscured
      expect( o.public_positional_accuracy ).not_to be_blank
      Observation.where( id: o.id ).update_all( public_positional_accuracy: nil )
      o.reload
      expect( o.read_attribute( :public_positional_accuracy ) ).to be_blank
      expect( o.public_positional_accuracy ).not_to be_blank
    end
  end
end

describe Observation, "probably_captive?" do
  elastic_models(Observation)

  describe "returns correct value" do
    let(:species) { create :taxon, :as_species }
    let(:place) { create :place, :with_geom, admin_level: Place::COUNTRY_LEVEL }

    def stub_observations(count=1, **kwargs)
      defaults = { captive: false, taxon: species, latitude: place.latitude, longitude: place.longitude }
      elastic_stub_observations(count) do
        build_stubbed(:observation, defaults.merge(**kwargs)) do |obs|
          allow(obs).to receive(:public_places).and_return [place]
          obs.update_quality_metrics
          obs.captive = obs.captive_cultivated
        end
      end
    end

    before do |e|
      allow(Observation).to receive(:system_places_for_latlon).and_return [place] unless e.metadata[:skip_before]
    end
    it "should be false with under 10 captive obs" do
      stub_observations 9, captive_flag: true

      expect(stub_observations).not_to be_probably_captive
    end
    it "should be true with more than 10 captive obs" do
      stub_observations 11, captive_flag: true

      expect(stub_observations).to be_probably_captive
    end
    it "should require more than 80% captive" do
      stub_observations 11
      stub_observations 11, captive_flag: true

      expect(stub_observations).not_to be_probably_captive
    end
    it "should be false with no coordinates", skip_before: true do
      stub_observations 11, captive_flag: true

      expect(stub_observations 1, latitude: nil, longitude: nil).not_to be_probably_captive
    end
    it "should be false with no taxon" do
      stub_observations 11, captive_flag: true

      expect(stub_observations 1, taxon: nil).not_to be_probably_captive
    end
    it "should use the community taxon if present" do
      stub_observations 11, captive_flag: true
      o = create :observation, latitude: place.latitude, longitude: place.longitude, prefers_community_taxon: false
      create_list :identification, 4, observation: o, taxon: species
      o.reload

      expect(o.taxon).not_to eq species
      expect(o.community_taxon).to eq species
      expect(o).to be_probably_captive
    end
  end

  describe Observation, "and update_quality_metrics" do
    let( :taxon ) { Taxon.make!( rank: Taxon::SPECIES ) }
    let( :place ) { make_place_with_geom( admin_level: Place::COUNTRY_LEVEL ) }
    def make_captive_obs
      Observation.make!( taxon: taxon, captive_flag: true, latitude: place.latitude, longitude: place.longitude )
    end
    def make_non_captive_obs
      Observation.make!( taxon: taxon, latitude: place.latitude, longitude: place.longitude )
    end
    it "should add a userless quality metric if probably_captive?" do
      11.times { make_captive_obs }
      o = make_non_captive_obs
      o.reload
      expect( o ).to be_captive
      expect(
        o.quality_metrics.detect{ |m| m.user_id.blank? && m.metric == QualityMetric::WILD }
      ).not_to be_blank
    end
    it "should remove the quality metric if not probably_captive? anymore" do
      11.times { make_captive_obs }
      o = make_non_captive_obs
      o.reload
      expect( o ).to be_captive
      11.times do
        obs = make_non_captive_obs
        QualityMetric.vote( nil, obs, QualityMetric::WILD, true )
      end
      o.update( description: "foo" )
      o.reload
      expect( o ).not_to be_captive
      expect(
        o.quality_metrics.detect{ |m| m.user_id.blank? && m.metric == QualityMetric::WILD }
      ).to be_blank
    end
  end
end

describe "ident getters" do
  it "should return taxon_id for a particular user by login" do
    u = User.make!( login: "balthazar_salazar" )
    i = Identification.make!( user: u )
    o = i.observation
    o.reload
    expect( o.send("ident_by_balthazar_salazar:taxon_id" ) ).to eq i.taxon_id
  end

  it "should return taxon name for a particular user by login" do
    u = User.make!( login: "balthazar_salazar" )
    i = Identification.make!( user: u )
    o = i.observation
    o.reload
    expect( o.send( "ident_by_balthazar_salazar:taxon_name" ) ).to eq i.taxon.name
  end

  it "should return taxon_id for a particular user by id" do
    u = User.make!
    i = Identification.make!( user: u )
    o = i.observation
    o.reload
    expect( o.send( "ident_by_#{u.id}:taxon_id" ) ).to eq i.taxon_id
  end
end

describe "observation field value getter" do
  it "should get the value of an observation field" do
    ofv = ObservationFieldValue.make!
    expect(
      ofv.observation.send("field:#{ofv.observation_field.name}")
    ).to eq ofv.value
  end

  it "should work for observation fields with colons" do
    of = ObservationField.make!( name: "dwc:locality" )
    ofv = ObservationFieldValue.make!( observation_field: of )
    expect(
      ofv.observation.send("field:#{ofv.observation_field.name}")
    ).to eq ofv.value
  end

  it "should work for observation fields with other non-word characters" do
    of = ObservationField.make!( name: "\% cover" )
    ofv = ObservationFieldValue.make!( observation_field: of )
    expect(
      ofv.observation.send("field:#{ofv.observation_field.name}")
    ).to eq ofv.value
  end
end

describe Observation, "and update_quality_metrics" do
  it "should not throw an error of owner ID taxon has no rank level" do
    o = make_research_grade_observation
    o.update( prefers_community_taxon: false )
    o.owners_identification.taxon.update( rank: "nonsense" )
    expect{
      o.get_quality_grade
    }.to_not raise_error
  end
end

describe Observation, "taxon_geoprivacy" do
  let!(:p) { make_place_with_geom }
  let!(:cs) { ConservationStatus.make!( place: p ) }
  let(:o) do
    o = Observation.make!
    Observation.where( id: o.id ).update_all(
      latitude: p.latitude + 10,
      longitude: p.longitude + 10,
      private_latitude: p.latitude,
      private_longitude: p.longitude,
    )
    o.reload
  end
  it "should be set using private coordinates" do
    expect( p ).to be_contains_lat_lng( o.private_latitude, o.private_longitude )
    expect( p ).not_to be_contains_lat_lng( o.latitude, o.longitude )
    i = Identification.make!( observation: o, taxon: cs.taxon )
    o.reload
    expect( o.taxon_geoprivacy ).to eq cs.geoprivacy
  end

  it "should restore taxon obscured coordinates when going from pivate to open" do
    i = Identification.make!( observation: o, taxon: cs.taxon )
    o.reload
    expect( o ).not_to be_coordinates_private
    expect( o ).to be_coordinates_obscured
    o.update( geoprivacy: Observation::PRIVATE )
    expect( o ).to be_coordinates_private
    o.reload
    o.update( geoprivacy: Observation::OPEN, latitude: o.private_latitude, longitude: o.private_longitude )
    o.reload
    expect( o ).not_to be_coordinates_private
    expect( o ).to be_coordinates_obscured
  end
end

describe Observation, "set_observations_taxa_for_user" do
  elastic_models( Observation )
  let(:user) { User.make! }
  let(:family1) { Taxon.make!( rank: Taxon::FAMILY, name: "Familyone" ) }
  let(:genus1) { Taxon.make!( rank: Taxon::GENUS, name: "Genusone", parent: family1 ) }
  let(:species1) { Taxon.make!( rank: Taxon::SPECIES, name: "Genusone speciesone", parent: genus1 ) }
  let(:o) do
    o = Observation.make!( user: user )
    i1 = Identification.make!( observation: o, user: user, taxon: genus1 )
    i2 = Identification.make!( observation: o, taxon: species1 )
    i3 = Identification.make!( observation: o, taxon: species1 )
    o
  end
  it "should change the community taxon if the observer's opted out of the community taxon" do
    expect( o.taxon ).to eq species1
    user.update( prefers_community_taxa: false )
    o.reload
    expect( o.taxon ).to eq species1
    Observation.set_observations_taxa_for_user( o.user_id )
    o.reload
    expect( o.taxon ).to eq genus1
  end
  it "should change the community taxon if the observer's opted in to the community taxon" do
    user.update( prefers_community_taxa: false )
    expect( o.taxon ).to eq genus1
    user.update( prefers_community_taxa: true )
    o.reload
    expect( o.taxon ).to eq genus1
    Observation.set_observations_taxa_for_user( o.user_id )
    o.reload
    expect( o.taxon ).to eq species1
  end
end

describe Observation, "set_time_zone" do
  before(:all) { load_time_zone_geometries }
  after(:all) { unload_time_zone_geometries }
  let(:oakland) { {
    lat: 37.7586346,
    lng: -122.3753932
  } }
  let(:tucson) { {
    lat: 32.1558328,
    lng: -111.023891
  } }
  let(:denver) { {
    lat: 39.7642548,
    lng: -104.9951965
  } }
  let(:pacific_ocean) { {
    lat: 22.204,
    lng: -123.836
  } }

  it "should default to the user time zone without coordinates" do
    o = Observation.make!
    expect( o.time_zone ).to eq o.user.time_zone
  end

  it "should set time zone based on location even if user time zone doesn't match" do
    o = Observation.make!( latitude: tucson[:lat], longitude: tucson[:lng] )
    expect( o.user.time_zone ).to eq "Pacific Time (US & Canada)"
    expect( o.time_zone ).to eq "Arizona"
    expect( o.zic_time_zone ).to eq "America/Phoenix"
  end

  it "should set time zone based on location even if observed_on_string doesn't match" do
    o = Observation.make!(
      observed_on_string: "2019-01-02 3:07:17 PM EST",
      latitude: oakland[:lat],
      longitude: oakland[:lng]
    )
    expect( o.time_zone ).to eq "Pacific Time (US & Canada)"
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
  end

  it "should change the time zone when the coordinates change" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng] )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: denver[:lat], longitude: denver[:lng] )
    expect( o.zic_time_zone ).to eq "America/Denver"
  end

  it "should change the time zone when the coordinates change when geoprivacy is obscured" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng], geoprivacy: Observation::OBSCURED )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: denver[:lat], longitude: denver[:lng] )
    expect( o.zic_time_zone ).to eq "America/Denver"
  end

  it "should work in the middle of the ocean" do
    o = Observation.make!(
      latitude: pacific_ocean[:lat],
      longitude: pacific_ocean[:lng]
    )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end

  it "should use the zic_time_zone as the time_zone in the middle of the ocean" do
    o = Observation.make!(
      latitude: pacific_ocean[:lat],
      longitude: pacific_ocean[:lng]
    )
    expect( o.time_zone ).to eq o.zic_time_zone
  end

  it "should work when coordinates change to the middle of the ocean" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng] )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: pacific_ocean[:lat], longitude: pacific_ocean[:lng] )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end

  it "should set the zic_time_zone in the middle of the ocean" do
    o = Observation.make!(
      latitude: pacific_ocean[:lat],
      longitude: pacific_ocean[:lng]
    )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end

  it "should set the zic_time_zone when coordinates change to the middle of the ocean" do
    o = Observation.make!( latitude: oakland[:lat], longitude: oakland[:lng] )
    expect( o.zic_time_zone ).to eq "America/Los_Angeles"
    o.update( latitude: pacific_ocean[:lat], longitude: pacific_ocean[:lng] )
    expect( o.zic_time_zone ).to eq "Etc/GMT+8"
  end
end

def setup_test_case_taxonomy
  # Tree:
  #          sf
  #          |
  #          f
  #       /     \
  #      g1     g2
  #     /  \
  #    s1  s2
  #   /  \
  # ss1  ss2

  # Superfamily intentionally left unavailable. Since it has a blank ancestry,
  # it will not really behave as expected in most tests
  sf = Taxon.make!( rank: "superfamily", name: "Superfamily" )
  @f = Taxon.make!( rank: "family", parent: sf, name: "Family" )
  @g1 = Taxon.make!( rank: "genus", parent: @f, name: "Genusone" )
  @g2 = Taxon.make!( rank: "genus", parent: @f, name: "Genustwo" )
  @s1 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciesone" )
  @s2 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciestwo" )
  @s3 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciesthree" )
  @s4 = Taxon.make!( rank: "species", parent: @g1, name: "Genusone speciesfour" )
  @ss1 = Taxon.make!( rank: "subspecies", parent: @s1, name: "Genusone speciesone subspeciesone" )
  @ss2 = Taxon.make!( rank: "subspecies", parent: @s1, name: "Genusone speciesone subspeciestwo" )
  @o = Observation.make!
end
