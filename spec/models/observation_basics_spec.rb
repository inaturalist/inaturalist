# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

# include ElasticStub

describe Observation do
  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to( :community_taxon ).class_name "Taxon" }
  it { is_expected.to belong_to( :iconic_taxon ).class_name( "Taxon" ).with_foreign_key "iconic_taxon_id" }
  it { is_expected.to belong_to :oauth_application }
  it { is_expected.to belong_to( :site ).inverse_of :observations }
  it { is_expected.to have_many( :observation_photos ).dependent( :destroy ).inverse_of :observation }
  it { is_expected.to have_many( :photos ).through :observation_photos }
  it { is_expected.to have_many( :listed_taxa ).with_foreign_key "last_observation_id" }
  it {
    is_expected.to have_many( :first_listed_taxa ).class_name( "ListedTaxon" ).with_foreign_key "first_observation_id"
  }
  it {
    is_expected.to have_many( :first_check_listed_taxa ).
      class_name( "ListedTaxon" ).
      with_foreign_key "first_observation_id"
  }
  it { is_expected.to have_many( :comments ).dependent :destroy }
  it { is_expected.to have_many( :annotations ).dependent :destroy }
  it { is_expected.to have_many( :identifications ).dependent :destroy }
  it { is_expected.to have_many( :project_observations ).dependent :destroy }
  it { is_expected.to have_many( :project_observations_with_changes ).class_name "ProjectObservation" }
  it { is_expected.to have_many( :projects ).through :project_observations }
  it { is_expected.to have_many( :quality_metrics ).dependent :destroy }
  it { is_expected.to have_many( :observation_field_values ).dependent( :destroy ).inverse_of :observation }
  it { is_expected.to have_many( :observation_fields ).through :observation_field_values }
  it { is_expected.to have_many :observation_links }
  it { is_expected.to have_and_belong_to_many :posts }
  it { is_expected.to have_many( :observation_sounds ).dependent( :destroy ).inverse_of :observation }
  it { is_expected.to have_many( :sounds ).through :observation_sounds }
  it { is_expected.to have_many :observations_places }
  it { is_expected.to have_many( :observation_reviews ).dependent :destroy }
  it { is_expected.to have_many( :confirmed_reviews ).class_name "ObservationReview" }

  context "when geo_x present" do
    subject { Observation.new geo_x: 1 }
    it { is_expected.to validate_presence_of :geo_y }
  end

  context "when geo_y present" do
    subject { Observation.new geo_y: 1 }
    it { is_expected.to validate_presence_of :geo_x }
  end

  it { is_expected.to validate_numericality_of( :geo_y ).allow_nil.with_message "should be a number" }
  it { is_expected.to validate_numericality_of( :geo_x ).allow_nil.with_message "should be a number" }
  it { is_expected.to validate_presence_of :user_id }
  it { is_expected.to validate_numericality_of( :latitude ).allow_nil.is_less_than( 90 ).is_greater_than( -90 ) }
  it { is_expected.to validate_length_of( :species_guess ).is_at_most( 256 ).allow_blank }
  it { is_expected.to validate_length_of( :place_guess ).is_at_most( 256 ).allow_blank }
  it do
    is_expected.to validate_numericality_of( :longitude ).allow_nil.is_less_than_or_equal_to( 180 ).
      is_greater_than_or_equal_to( -180 )
  end
end

describe Observation do
  before( :all ) do
    DatabaseCleaner.clean_with( :truncation, except: %w(spatial_ref_sys) )
  end

  elastic_models( Observation, Taxon )

  describe "creation" do
    subject { build :observation }

    describe "parses and sets time" do
      context "with observed_on_string" do
        subject { build_stubbed :observation, :without_times }

        before do | spec |
          subject.observed_on_string = spec.metadata[:time]
          subject.run_callbacks :validation
        end

        it "should be in the past", time: "April 1st 1994 at 1am" do
          expect( subject.observed_on ).to be <= Date.today
        end

        it "should properly set date and time", time: "April 1st 1994 at 1am" do
          Time.use_zone( subject.time_zone ) do
            expect( subject.observed_on.year ).to eq 1994
            expect( subject.observed_on.month ).to eq 4
            expect( subject.observed_on.day ).to eq 1
            expect( subject.time_observed_at.hour ).to eq 1
          end
        end

        it "should parse time from strings like October 30, 2008 10:31PM", time: "October 30, 2008 10:31PM" do
          expect( subject.time_observed_at.in_time_zone( subject.time_zone ).hour ).to eq 22
        end

        it "should parse time from strings like 2011-12-23T11:52:06-0500", time: "2011-12-23T11:52:06-0500" do
          expect( subject.time_observed_at.in_time_zone( subject.time_zone ).hour ).to eq 11
        end

        it "should parse time from strings like 2011-12-23 11:52:06 -05", time: "2011-12-23 11:52:06 -05" do
          expect( subject.time_observed_at.in_time_zone( subject.time_zone ).hour ).to eq 11
        end

        it "should parse time from strings like 2011-12-23T11:52:06.123", time: "2011-12-23T11:52:06.123" do
          expect( subject.time_observed_at.in_time_zone( subject.time_zone ).hour ).to eq 11
        end

        it "should parse time and zone from July 9, 2012 7:52:39 AM ACST", time: "July 9, 2012 7:52:39 AM ACST" do
          expect( subject.time_observed_at.in_time_zone( subject.time_zone ).hour ).to eq 7
          expect( subject.time_zone ).to eq ActiveSupport::TimeZone["Adelaide"].name
        end

        it "should handle unparsable times gracefully", time: "2013-03-02, 1430hrs" do
          expect( subject.observed_on.day ).to eq 2
        end

        it "should not save a time if one wasn't specified", time: "April 2 2008" do
          expect( subject.time_observed_at ).to be_blank
        end

        it "should not save a time for 'today'", time: "today" do
          expect( subject.time_observed_at ).to be( nil )
        end

        it "should parse a time zone from a code", time: "October 30, 2008 10:31PM EST" do
          expect( subject.time_zone ).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].name
        end

        it "should parse time zone from strings like '2011-12-23T11:52:06-0500'", time: "2011-12-23T11:52:06-0500" do
          expect( subject.time_zone ).not_to be_blank
          expect( ActiveSupport::TimeZone[subject.time_zone].formatted_offset ).to eq "-05:00"
        end

        it "should not save relative dates/times like 'this morning'", time: "this morning" do
          expect( subject.observed_on_string.match( "this morning" ) ).to be( nil )
        end

        it "should preserve observed_on_string if it did NOT contain a relative time descriptor",
          time: "April 22 2008" do
          expect( subject.observed_on_string ).to eq "April 22 2008"
        end

        it "should parse dates that contain commas", time: "April 22, 2008" do
          expect( subject.observed_on ).not_to be( nil )
        end

        it "should NOT parse a date like '2004'", time: "2004" do
          expect( subject ).not_to be_valid
        end

        it "should properly parse relative datetimes like '2 days ago'", time: "2 days ago" do
          Time.use_zone( subject.user.time_zone ) do
            expect( subject.observed_on ).to eq 2.days.ago.to_date
          end
        end

        it "should not save relative dates/times like 'yesterday'", time: "yesterday" do
          expect( subject.observed_on_string.split.include?( "yesterday" ) ).to be( false )
        end

        it "should default to the user's time zone" do
          expect( subject.time_zone ).to eq subject.user.time_zone
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
        let( :u_est ) { build_stubbed :user, time_zone: "Eastern Time (US & Canada)" }
        let( :u_cot ) { build_stubbed :user, time_zone: "Bogota" }

        it "should use the user's time zone if the date string only has an offset and it matches " \
          "the user's time zone" do
          o_est = build_stubbed :observation,
            :without_times,
            user: u_est,
            observed_on_string: "2019-01-29 9:21:46 a. m. GMT-05:00"
          o_est.run_callbacks :validation
          expect( o_est.time_zone ).to eq u_est.time_zone
          o_cot = build_stubbed :observation,
            :without_times,
            user: u_cot,
            observed_on_string: "2019-01-29 9:21:46 a. m. GMT-05:00"
          o_cot.run_callbacks :validation
          expect( o_cot.time_zone ).to eq u_cot.time_zone
        end

        it "should use the user's time zone if the date string only has an offset and it matches " \
          "the user's time zone during daylight savings time" do
          o_est = build_stubbed :observation,
            :without_times,
            user: u_est,
            observed_on_string: "2018-06-29 9:21:46 a. m. GMT-05:00"
          o_est.run_callbacks :validation
          expect( o_est.time_zone ).to eq u_est.time_zone
          o_cot = build_stubbed :observation,
            :without_times,
            user: u_cot,
            observed_on_string: "2018-06-29 9:21:46 a. m. GMT-05:00"
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
        subject.time_zone = "Eastern Time (US & Canada)"
        subject.run_callbacks :validation

        expect( subject.time_zone ).not_to eq subject.user.time_zone
        expect( subject.time_zone ).to eq "Eastern Time (US & Canada)"
      end

      it "should save the time in the time zone selected" do
        subject.time_zone = "Eastern Time (US & Canada)"
        subject.run_callbacks :validation

        expect( subject.time_observed_at.in_time_zone( subject.time_zone ).hour ).to eq 12
      end

      it "should not choke of bad dates" do
        observation = create :observation, :without_times
        observation.observed_on_string = "this is not a date"

        expect { observation.save }.not_to raise_error
      end

      it "should not be in the future" do
        expect do
          create :observation, :without_times,
            observed_on_string: "2 weeks from now"
        end.to raise_error( ActiveRecord::RecordInvalid )
      end

      it "should parse a bunch of test date strings" do
        [
          ["Fri Apr 06 2012 16:23:35 GMT-0500 (GMT-05:00)", { month: 4, day: 6, hour: 16, offset: "-05:00" }],
          ["Sun Nov 03 2013 08:15:25 GMT-0500 (GMT-5)", { month: 11, day: 3, hour: 8, offset: "-05:00" }],

          # This won't work given our current setup because if we lookup a time
          # zone by offset like this, it will return the first *named* timezone,
          # which in this case is Amsterdam, which is the same as CET, which, in
          # September, observes daylight savings time, so it's actually CEST and
          # the offset is +2:00. The main problem here is that if the client just
          # specifies an offset, we can't reliably find the zone
          # ['September 27, 2012 8:09:50 AM GMT+01:00', :month => 9, :day => 27, :hour => 8, :offset => "+01:00"],

          # This *does* work b/c in December, Amsterdam is in CET, standard time
          ["December 27, 2012 8:09:50 AM GMT+01:00", { month: 12, day: 27, hour: 8, offset: "+01:00" }],
          # Spacy AM, offset w/o named zone
          ["2019-01-29 9:21:46 a. m. GMT-05:00", { month: 1, day: 29, hour: 9, offset: "-05:00" }],
          ["Thu Dec 26 2013 11:18:22 GMT+0530 (GMT+05:30)", { month: 12, day: 26, hour: 11, offset: "+05:30" }],
          ["Thu Feb 20 2020 11:46:32 GMT+1030 (GMT+10:30)", { month: 2, day: 20, hour: 11, offset: "+10:30" }],
          ["Thu Feb 20 2020 11:46:32 GMT+10:30", { month: 2, day: 20, hour: 11, offset: "+10:30" }],
          # ['2010-08-23 13:42:55 +0000', :month => 8, :day => 23, :hour => 13, :offset => "+00:00"],
          ["2014-06-18 5:18:17 pm CEST", { month: 6, day: 18, hour: 17, offset: "+02:00" }],
          ["2017-03-12 12:17:00 pm PDT", { month: 3, day: 12, hour: 12, offset: "-07:00" }],
          ["2017/03/12 12:17 PM PDT", { month: 3, day: 12, hour: 12, offset: "-07:00" }],
          ["2017/03/12 12:17 P.M. PDT", { month: 3, day: 12, hour: 12, offset: "-07:00" }],
          # ["2017/03/12 12:17 AM PDT", month: 3, day: 12, hour: 0, offset: "-07:00"], # this doesn't work.. why...
          ["2017/04/12 12:17 AM PDT", { month: 4, day: 12, hour: 0, offset: "-07:00" }],
          ["2020/09/02 8:28 PM UTC", { month: 9, day: 2, hour: 20, offset: "+00:00" }],
          ["2020/09/02 8:28 PM GMT", { month: 9, day: 2, hour: 20, offset: "+00:00" }],
          ["2021-03-02T13:00:10.000-06:00", { month: 3, day: 2, hour: 13, offset: "-06:00" }],
          ["Mon Feb 14 2022 09:41:56 GMT-0500 (EST)", { month: 2, day: 14, hour: 9, offset: "-05:00" }]
        ].each do | date_string, opts |
          observation = build :observation, :without_times, observed_on_string: date_string
          observation.run_callbacks :validation

          expect( observation.observed_on.day ).to eq opts[:day]
          expect( observation.observed_on.month ).to eq opts[:month]
          time = observation.time_observed_at.in_time_zone( observation.time_zone )
          expect( time.hour ).to eq opts[:hour]
          expect( time.formatted_offset ).to eq opts[:offset]
        end
      end

      it "should parse Spanish date strings" do
        [
          ["lun nov 04 2013 04:22:34 p.m. GMT-0600 (GMT-6)", { month: 11, day: 4, hour: 16, offset: "-06:00" }],
          ["lun dic 09 2013 23:37:08 GMT-0800 (GMT-8)", { month: 12, day: 9, hour: 23, offset: "-08:00" }],
          ["jue dic 12 2013 00:54:02 GMT-0800 (GMT-8)", { month: 12, day: 12, hour: 0, offset: "-08:00" }]
        ].each do | date_string, opts |
          observation = build :observation, :without_times, observed_on_string: date_string
          observation.run_callbacks :validation

          expect( ActiveSupport::TimeZone[observation.time_zone].formatted_offset ).to eq opts[:offset]
          expect( observation.observed_on.month ).to eq( opts[:month] )
          expect( observation.observed_on.day ).to eq opts[:day]
          expect( observation.time_observed_at.in_time_zone( observation.time_zone ).hour ).to eq opts[:hour]
        end
      end

      it "should handle a user without a time zone" do
        observation = build :observation, :without_times, user: build( :user, time_zone: nil ),
                                          observed_on_string: "2018-06-29 9:21:46 a. m. GMT-05:00"
        observation.run_callbacks :validation

        expect( observation.observed_on ).not_to be_blank
      end

      it "should set the time zone to UTC if the user's time zone is blank" do
        observation = build :observation, :without_times, observed_on_string: nil, user: build( :user, time_zone: nil )
        observation.run_callbacks :validation

        expect( observation.time_zone ).to eq "UTC"
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

      expect( observation.identifications.empty? ).not_to be( true )
      expect( observation.identifications.first.taxon ).to eq observation.taxon
    end

    it "should not have an identification if taxon is not known" do
      observation = create :observation, taxon: nil

      expect( observation.identifications.to_a ).to be_blank
    end

    it "should not queue a DJ job to refresh lists" do
      Delayed::Job.delete_all
      stamp = Time.now
      Observation.make!( taxon: Taxon.make! )
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      expect( jobs.select {| j | j.handler =~ /List.*refresh_with_observation/m } ).to be_blank
    end

    it "should trim whitespace from species_guess" do
      observation = create :observation, species_guess: " Anna's Hummingbird     "

      expect( observation.species_guess ).to eq "Anna's Hummingbird"
    end

    it "should increment the counter cache in users" do
      observation = create :observation
      Delayed::Worker.new.work_off
      observation.reload
      old_count = observation.user.observations_count
      Observation.make!( user: observation.user )
      Delayed::Worker.new.work_off
      observation.reload
      expect( observation.user.observations_count ).to eq old_count + 1
    end

    describe "setting lat lon" do
      let( :lat ) { 37.91143999 }
      let( :lon ) { -122.2687819 }

      it "sets latlon and place guess on save" do
        observation = create :observation

        expect( observation ).to receive( :set_latlon_from_place_guess )
        expect( observation ).to receive( :set_place_guess_from_latlon )
        observation.save
      end

      it "should allow lots of sigfigs" do
        observation = create :observation, latitude: lat, longitude: lon

        expect( observation.latitude.to_f ).to eq lat
        expect( observation.longitude.to_f ).to eq lon
      end

      it "should set lat/lon if entered in place_guess" do
        observation = build :observation, latitude: nil, longitude: nil, place_guess: "#{lat}, #{lon}"
        observation.set_latlon_from_place_guess

        expect( observation.latitude.to_f ).to eq lat
        expect( observation.longitude.to_f ).to eq lon
      end

      it "should set lat/lon if entered in place_guess as NSEW" do
        observation = build :observation, latitude: nil, longitude: nil, place_guess: "S#{lat * -1}, W#{lon * -1}"
        observation.set_latlon_from_place_guess

        expect( observation.latitude.to_f ).to eq lat * -1
        expect( observation.longitude.to_f ).to eq lon
      end

      it "should not set lat/lon for addresses with numbers" do
        observation = build :observation, place_guess: "Apt 1, 33 Figueroa Ave., Somewhere, CA"
        observation.set_latlon_from_place_guess

        expect( observation.latitude ).to be_blank
      end

      it "should not set lat/lon for addresses with zip codes" do
        observation = build :observation, place_guess: "94618"
        observation.set_latlon_from_place_guess

        expect( observation.latitude ).to be_blank

        observation2 = build :observation, place_guess: "94618-5555"
        observation.set_latlon_from_place_guess

        expect( observation2.latitude ).to be_blank
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
        expect( o.place_guess ).to match /#{small_place.name}/
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
        expect( o.place_guess ).to match /#{small_place.name}/
        expect( o.place_guess ).to match /#{big_place.name}/
      end
      it "should not include places without admin_level" do
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        expect( user_place.admin_level ).to be_blank
        expect( o.place_guess ).not_to match /#{user_place.name}/
      end

      it "should only use places that contain the public_positional_accuracy" do
        swlat, swlng, nelat, _nelng = small_place.bounding_box

        place_left_side = lat_lon_distance_in_meters( swlat, swlng, nelat, swlng )
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
        expect( o.place_guess ).not_to match /#{small_place.name}/
        expect( o.place_guess ).to match /#{big_place.name}/
      end
      it "should use codes when available" do
        big_place.update( code: "USA" )
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude )
        expect( o.place_guess ).to match /#{big_place.code}/
        expect( o.place_guess ).not_to match /#{big_place.name}/
      end
      it "should use names translated for the observer" do
        big_place.update( name: "Mexico" )
        user = User.make!( locale: "es-MX" )
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude, user: user )
        expect( o.place_guess ).to match /#{I18n.t( "places_name.mexico", locale: user.locale )}/
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
        o = Observation.make!( latitude: small_place.latitude, longitude: small_place.longitude,
          geoprivacy: Observation::PRIVATE )
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

        expect( subject.quality_grade ).to eq Observation::CASUAL
      end
    end

    it "should trim to the user_agent to 255 char" do
      observation = create :observation, user_agent: <<-USER_AGENT
        Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR
        1.0.3705; .NET CLR 1.1.4322; Media Center PC 4.0; .NET CLR 2.0.50727;
        .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; .NET CLR 3.0.4506.2152;
        .NET CLR 3.5.30729; PeoplePal 7.0; PeoplePal 7.3; .NET4.0C; .NET4.0E;
        OfficeLiveConnector.1.5; OfficeLivePatch.1.3) w:PACBHO60
      USER_AGENT

      expect( observation.user_agent.size ).to be < 256
    end

    it "should set the URI" do
      o = Observation.make!
      o.reload
      expect( o.uri ).to eq( UrlHelper.observation_url( o ) )
    end

    it "should not set the URI if already set" do
      uri = "http://www.somewhereelse.com/users/4"
      o = Observation.make!( uri: uri )
      o.reload
      expect( o.uri ).to eq( uri )
    end

    it "should increment the taxon's counter cache" do
      t = without_delay { Taxon.make! }
      expect( t.observations_count ).to eq 0
      without_delay { Observation.make!( taxon: t ) }
      t.reload
      expect( t.observations_count ).to eq 1
    end

    it "should increment the taxon's ancestors' counter caches" do
      p = without_delay { Taxon.make!( rank: Taxon::GENUS ) }
      t = without_delay { Taxon.make!( parent: p, rank: Taxon::SPECIES ) }
      expect( p.observations_count ).to eq 0
      without_delay { Observation.make!( taxon: t ) }
      p.reload
      expect( p.observations_count ).to eq 1
    end

    it "should be georeferenced? with zero degrees" do
      expect( Observation.make!( longitude: 1, latitude: 1 ) ).to be_georeferenced
    end

    it "should not be georeferenced with nil degrees" do
      expect( Observation.make!( longitude: 1, latitude: nil ) ).not_to be_georeferenced
    end

    it "should be georeferenced? even with private geoprivacy" do
      o = Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE )
      expect( o ).to be_georeferenced
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
      o = Observation.make!( geoprivacy: Observation::OBSCURED, latitude: 1.1, longitude: 2.2 )
      expect( o.coordinates_obscured? ).to be true
      expect( o.calculate_public_positional_accuracy ).to eq o.uncertainty_cell_diagonal_meters
    end

    it "should set public accuracy to the greater of accuracy and M_TO_OBSCURE_THREATENED_TAXA" do
      lat = 1.1
      lon = 2.2
      uncertainty_cell_diagonal_meters = Observation.uncertainty_cell_diagonal_meters( lat, lon )
      o = Observation.make!( geoprivacy: Observation::OBSCURED, latitude: lat, longitude: lon,
        positional_accuracy: uncertainty_cell_diagonal_meters + 1 )
      expect( o.calculate_public_positional_accuracy ).to eq o.uncertainty_cell_diagonal_meters + 1
    end

    it "should set public accuracy to accuracy" do
      expect( Observation.make!( positional_accuracy: 10 ).public_positional_accuracy ).to eq 10
    end

    it "should set public accuracy to nil if accuracy is nil" do
      expect( Observation.make!( positional_accuracy: nil ).public_positional_accuracy ).to be_nil
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
        Delayed::Job.find_each( &:invoke_job )
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

    it "should set time_zone to a Rails time zone when a zic time zone we know about was specified but Rails " \
      "ignores it" do
      ignored_time_zones = { "America/Toronto" => "Eastern Time (US & Canada)" }
      ignored_time_zones.each do | tz_name, rails_name |
        o = Observation.make!( time_zone: tz_name )
        expect( o.time_zone ).to eq rails_name
      end
    end

    it "should set time_zone to the zic time zone when a zic time zone we don't know about was specified but Rails " \
      "ignores it" do
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
      after_delayed_job_finishes { Identification.make!( observation: o, user: o.user ) }
      o.reload
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 1
    end

    it "should not create an obs review identified by someone else" do
      o = Observation.make!
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 0
      after_delayed_job_finishes { Identification.make!( observation: o ) }
      o.reload
      expect( o.observation_reviews.where( user: o.user_id ).count ).to eq 0
    end

    it "should not destroy the owner's old identification if the taxon has changed" do
      t1 = Taxon.make!
      t2 = Taxon.make!
      o = Observation.make!( taxon: t1 )
      old_owners_ident = o.identifications.detect {| ident | ident.user_id == o.user_id }
      o.update( taxon: t2, editing_user_id: o.user_id )
      o.reload
      expect( Identification.find_by_id( old_owners_ident.id ) ).not_to be_blank
    end

    it "should not destroy the owner's old identification if the taxon has changed unless it's the owner's only " \
      "identification" do
      t1 = Taxon.make!
      o = Observation.make!( taxon: t1 )
      old_owners_ident = o.identifications.detect {| ident | ident.user_id == o.user_id }
      o.update( taxon: nil, editing_user_id: o.user_id )
      o.reload
      expect( Identification.find_by_id( old_owners_ident.id ) ).to be_blank
    end

    describe "observed_on_string" do
      let( :observation ) do
        Observation.make!(
          taxon: Taxon.make!,
          observed_on_string: "yesterday at 1pm",
          time_zone: "UTC"
        )
      end
      it "should properly set date and time" do
        observation.observed_on_string = "March 16 2007 at 2pm"
        observation.save
        expect( observation.observed_on ).to eq Date.parse( "2007-03-16" )
        expect( observation.time_observed_at_in_zone.hour ).to eq( 14 )
      end

      it "should not save a time if one wasn't specified" do
        observation.update( observed_on_string: "April 2 2008" )
        observation.save
        expect( observation.time_observed_at ).to be_blank
      end

      it "should clear date if observed_on_string blank" do
        expect( observation.observed_on ).not_to be_blank
        observation.update( observed_on_string: "" )
        expect( observation.observed_on ).to be_blank
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
      expect( obs.iconic_taxon ).to be_blank
      taxon = Taxon.make!( iconic_taxon: Taxon.make!( is_iconic: true ) )
      expect( taxon.iconic_taxon ).not_to be_blank
      obs.taxon = taxon
      obs.editing_user_id = obs.user_id
      obs.save!
      expect( obs.iconic_taxon.name ).to eq taxon.iconic_taxon.name
    end

    it "should remove an iconic taxon if the taxon was removed" do
      taxon = Taxon.make!( iconic_taxon: Taxon.make!( is_iconic: true ) )
      expect( taxon.iconic_taxon ).not_to be_blank
      obs = Observation.make!( taxon: taxon )
      expect( obs.iconic_taxon ).not_to be_blank
      obs.taxon = nil
      obs.editing_user_id = obs.user_id
      obs.save!
      obs.reload
      expect( obs.iconic_taxon ).to be_blank
    end

    it "should not queue refresh jobs for associated project lists if the taxon changed" do
      o = Observation.make!( taxon: Taxon.make! )
      pu = ProjectUser.make!( user: o.user )
      ProjectObservation.make!( observation: o, project: pu.project )
      Delayed::Job.delete_all
      stamp = Time.now
      o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      expect( jobs.select {| j | j.handler =~ /ProjectList.*refresh_with_observation/m } ).to be_blank
    end

    it "should queue refresh job for check lists if the coordinates changed" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      o.update( latitude: o.latitude + 1 )
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      expect( jobs.select {| j | j.handler =~ /CheckList.*refresh_with_observation/m } ).not_to be_blank
    end

    it "should not queue job to refresh life lists if taxon changed" do
      o = Observation.make!( taxon: Taxon.make! )
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      end
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      expect( jobs.select {| j | j.handler =~ /LifeList.*refresh_with_observation/m }.size ).to eq( 0 )
    end

    it "should not queue job to refresh project lists if taxon changed" do
      po = make_project_observation( taxon: Taxon.make! )
      o = po.observation
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      end
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      expect( jobs.select {| j | j.handler =~ /ProjectList.*refresh_with_observation/m }.size ).to eq( 0 )
    end

    it "should only queue one check list refresh job" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      3.times do
        o.update( latitude: o.latitude + 1 )
      end
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      expect( jobs.select {| j | j.handler =~ /CheckList.*refresh_with_observation/m }.size ).to eq( 1 )
    end

    it "should queue refresh job for check lists if the taxon changed" do
      o = make_research_grade_observation
      Delayed::Job.delete_all
      stamp = Time.now
      o = Observation.find( o.id )
      o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      pattern = /CheckList.*refresh_with_observation/m
      job = jobs.detect {| j | j.handler =~ pattern }
      expect( job ).not_to be_blank
      # puts job.handler.inspect
    end

    it "should not queue refresh job for project lists if the taxon changed" do
      po = make_project_observation
      o = po.observation
      Delayed::Job.delete_all
      stamp = Time.now
      o.update( taxon: Taxon.make!, editing_user_id: o.user_id )
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      pattern = /ProjectList.*refresh_with_observation/m
      job = jobs.detect {| j | j.handler =~ pattern }
      expect( job ).to be_blank
      # puts job.handler.inspect
    end

    it "should not allow impossible coordinates" do
      o = Observation.make!
      o.update( latitude: 100 )
      expect( o ).not_to be_valid

      o = Observation.make!
      o.update( longitude: 200 )
      expect( o ).not_to be_valid

      o = Observation.make!
      o.update( latitude: -100 )
      expect( o ).not_to be_valid

      o = Observation.make!
      o.update( longitude: -200 )
      expect( o ).not_to be_valid
    end

    it "should add the taxon to a check list for an enclosing place if the quality became research" do
      t = Taxon.make!( :species )
      p = without_delay { make_place_with_geom }
      o = without_delay do
        make_research_grade_candidate_observation( latitude: p.latitude, longitude: p.longitude, taxon: t )
      end
      expect( p.check_list.taxa ).not_to include t
      without_delay { Identification.make!( observation: o, taxon: t ) }
      o.reload
      expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      p.reload
      expect( p.check_list.taxa ).to include t
    end

    describe "quality_grade" do
      it "should become research when it qualifies" do
        o = Observation.make!( taxon: Taxon.make!( rank: "species" ), latitude: 1, longitude: 1 )
        Identification.make!( observation: o, taxon: o.taxon )
        o.photos << LocalPhoto.make!( user: o.user )
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
        o.update( observed_on_string: "yesterday" )
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be research grade if community taxon at family or lower" do
        o = make_research_grade_candidate_observation( taxon: Taxon.make!( rank: "species" ) )
        Identification.make!( observation: o, taxon: o.taxon )
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should not be research grade if community taxon above family" do
        o = make_research_grade_candidate_observation( taxon: Taxon.make!( rank: "order" ) )
        Identification.make!( observation: o, taxon: o.taxon )
        o.reload
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      it "should become needs ID when taxon changes" do
        o = make_research_grade_observation
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        new_taxon = Taxon.make!
        o = Observation.find( o.id )
        o.update( taxon: new_taxon, editing_user_id: o.user_id )
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      it "should become casual when date removed" do
        o = make_research_grade_observation
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
        o.update( observed_on_string: "" )
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be research when community taxon is obs taxon and owner agrees" do
        o = make_research_grade_observation
        o.identifications.destroy_all
        o.reload
        parent = Taxon.make!( rank: "genus" )
        child = Taxon.make!( parent: parent, rank: "species" )
        _i1 = Identification.make!( observation: o, taxon: parent )
        _i2 = Identification.make!( observation: o, taxon: child )
        _i3 = Identification.make!( observation: o, taxon: child, user: o.user )
        o.reload
        expect( o.community_taxon ).to eq child
        expect( o.taxon ).to eq child
        expect( o ).to be_community_supported_id
        expect( o ).to be_research_grade
      end

      it "should be needs ID if no identifications" do
        o = make_research_grade_observation
        o.identifications.destroy_all
        o.reload
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      it "should not be research if the community taxon is Life" do
        load_test_taxa
        o = make_research_grade_observation
        o.identifications.destroy_all
        _i1 = Identification.make!( observation: o, taxon: @Animalia )
        _i2 = Identification.make!( observation: o, taxon: @Plantae )
        o.reload
        expect( o.community_taxon ).to eq @Life
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
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
        _i = Identification.make!( observation: o, taxon: t )
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
        Flag.make!( flaggable: o, flag: Flag::SPAM )
        o.reload
        expect( o ).not_to be_appropriate
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual if photos flagged" do
        o = make_research_grade_observation
        Flag.make!( flaggable: o.photos.first, flag: Flag::COPYRIGHT_INFRINGEMENT )
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be research grade if community ID at species or lower and research grade candidate" do
        o = make_research_grade_candidate_observation
        t = Taxon.make!( rank: Taxon::SPECIES )
        2.times { Identification.make!( observation: o, taxon: t ) }
        expect( o.community_taxon.rank ).to eq Taxon::SPECIES
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be casual if community ID at species or lower and not research grade candidate" do
        o = Observation.make!
        t = Taxon.make!( rank: Taxon::SPECIES )
        2.times { Identification.make!( observation: o, taxon: t ) }
        expect( o.community_taxon.rank ).to eq Taxon::SPECIES
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be needs ID if elligible" do
        o = make_research_grade_candidate_observation
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      it "should be casual if voted out" do
        o = Observation.make!
        o.downvote_from User.make!, vote_scope: "needs_id"
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should not notify the observer if voted out" do
        # ,queue_if: lambda { |record| record.vote_scope.blank? }
        o = Observation.make!
        without_delay do
          expect do
            o.downvote_from User.make!, vote_scope: "needs_id"
          end.not_to change( UpdateAction, :count )
        end
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual by default" do
        o = Observation.make!
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be casual if verifiable but voted out and community taxon above family" do
        o = make_research_grade_candidate_observation( taxon: Taxon.make!( rank: Taxon::ORDER ) )
        Identification.make!( observation: o, taxon: o.taxon )
        o.reload
        expect( o.community_taxon.rank ).to eq Taxon::ORDER
        o.downvote_from User.make!, vote_scope: "needs_id"
        o.reload
        expect( o.quality_grade ).to eq Observation::CASUAL
      end

      it "should be research grade if verifiable but voted out and community taxon below family" do
        o = make_research_grade_candidate_observation
        t = Taxon.make!( rank: Taxon::GENUS )
        2.times do
          Identification.make!( taxon: t, observation: o )
        end
        o.reload
        expect( o.community_taxon ).to eq t
        o.downvote_from User.make!, vote_scope: "needs_id"
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be research grade if verifiable but voted out and community taxon below family but above genus" do
        o = make_research_grade_candidate_observation
        t = Taxon.make!( rank: Taxon::SUBFAMILY )
        2.times do
          Identification.make!( taxon: t, observation: o )
        end
        o.reload
        expect( o.community_taxon ).to eq t
        o.downvote_from User.make!, vote_scope: "needs_id"
        o.reload
        expect( o.quality_grade ).to eq Observation::RESEARCH_GRADE
      end

      it "should be needs ID if verifiable and voted back in" do
        o = make_research_grade_candidate_observation
        o.downvote_from User.make!, vote_scope: "needs_id"
        o.upvote_from User.make!, vote_scope: "needs_id"
        Observation.set_quality_grade( o.id )
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
        o = make_research_grade_candidate_observation( taxon: Taxon.make!( :species ) )
        o.downvote_from User.make!, vote_scope: "needs_id"
        expect( o.identifications.count ).to eq 1
        expect( o.quality_grade ).to eq Observation::NEEDS_ID
      end

      describe "when observer opts out of CID" do
        let( :u ) { User.make!( prefers_community_taxa: false ) }
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
          let( :genus ) { Taxon.make!( rank: Taxon::GENUS ) }
          let( :o ) { make_research_grade_candidate_observation( taxon: genus, user: u ) }
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
        it "should be casual if there are conservative disagreements with the observer and the community " \
          "votes it out of needs_id" do
          genus = Taxon.make!( rank: Taxon::GENUS )
          species = Taxon.make!( rank: Taxon::SPECIES, parent: genus )
          o = make_research_grade_candidate_observation( prefers_community_taxon: false, taxon: species )
          2.times { Identification.make!( observation: o, taxon: genus ) }
          o.reload
          expect( o.quality_grade ).to eq Observation::NEEDS_ID
          o.downvote_from User.make!, vote_scope: "needs_id"
          o.reload
          expect( o.quality_grade ).to eq Observation::CASUAL
        end
        it "should be research if the taxon matches the CID taxon and the CID taxon is a subgenus and " \
          "voted out of needs_id" do
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
        it "should be research if the taxon matches the CID taxon and the CID taxon is a subfamily and " \
          "voted out of needs_id" do
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
      let( :place ) { make_place_with_geom }
      let( :species ) { create :taxon, :as_species }
      it "should obscure coordinates if taxon has a conservation status in the place observed" do
        create :conservation_status, place: place, taxon: species
        o = create :observation, latitude: place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).to be_coordinates_obscured
      end

      it "should not obscure coordinates if taxon has a conservation status in another place" do
        create :conservation_status, place: place, taxon: species
        o = create :observation, latitude: -1 * place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).not_to be_coordinates_obscured
      end

      it "should obscure coordinates if locally threatened but globally secure" do
        _local_cs = create :conservation_status, place: place, taxon: species
        _global_cs = create :conservation_status,
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
        _local_cs = create :conservation_status,
          place: place,
          taxon: species,
          status: "LC",
          iucn: Taxon::IUCN_LEAST_CONCERN,
          geoprivacy: Observation::OPEN
        _global_cs = create :conservation_status, taxon: species
        o = create :observation, latitude: place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).not_to be_coordinates_obscured
      end

      it "should obscure coordinates if secure in state and globally threatened and another suggested " \
        "taxon is globally threatened" do
        place.update( admin_level: Place::STATE_LEVEL )
        _local_cs1 = create :conservation_status,
          place: place,
          taxon: species,
          status: "LC",
          iucn: Taxon::IUCN_LEAST_CONCERN,
          geoprivacy: Observation::OPEN
        _global_cs1 = create :conservation_status, taxon: species
        global_cs2 = create :conservation_status
        o = create :observation, latitude: place.latitude, longitude: place.longitude, taxon: species
        expect( o ).not_to be_coordinates_obscured
        create :identification, observation: o, taxon: global_cs2.taxon
        expect( o ).to be_coordinates_obscured
      end

      it "should obscure coordinates if secure in state and globally threatened and another suggested " \
        "taxon is threatened in an overlapping state" do
        place1 = make_place_with_geom( admin_level: Place::STATE_LEVEL )
        place2 = make_place_with_geom( admin_level: Place::STATE_LEVEL )
        _local_cs1 = create :conservation_status,
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
        _global_cs = create :conservation_status, taxon: species
        o = create :observation, latitude: place.latitude, longitude: place.longitude, taxon: species
        expect( o ).not_to be_coordinates_obscured
        create :identification, observation: o, taxon: local_cs2.taxon
        expect( o ).to be_coordinates_obscured
      end

      it "should not obscure coordinates if conservation statuses exist but all are open" do
        _cs = create :conservation_status, place: place, taxon: species, geoprivacy: Observation::OPEN
        _cs_global = create :conservation_status, taxon: species, geoprivacy: Observation::OPEN
        o = create :observation, latitude: -1 * place.latitude, longitude: place.longitude
        expect( o ).not_to be_coordinates_obscured
        o.update( taxon: species, editing_user_id: o.user_id )
        expect( o ).not_to be_coordinates_obscured
      end

      describe "when at least one ID is of a threatened taxon" do
        let( :o ) { make_research_grade_observation( latitude: place.latitude, longitude: place.longitude ) }
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
          _global_cs = create :conservation_status,
            taxon: species,
            iucn: Taxon::IUCN_LEAST_CONCERN,
            geoprivacy: Observation::OPEN
          _local_cs = create :conservation_status, place: place, taxon: species
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).to be_coordinates_obscured
        end
        it "should not obscure coordinates if secure in state but globally threatened" do
          expect( o ).not_to be_coordinates_obscured
          place.update( admin_level: Place::STATE_LEVEL )
          _local_cs = create :conservation_status,
            place: place,
            taxon: species,
            iucn: Taxon::IUCN_LEAST_CONCERN,
            geoprivacy: Observation::OPEN
          _global_cs = create :conservation_status, taxon: species
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).not_to be_coordinates_obscured
        end
        it "should not obscure coordinates if conservation statuses exist but all are open" do
          expect( o ).not_to be_coordinates_obscured
          _global_cs = create :conservation_status, taxon: species, geoprivacy: Observation::OPEN
          _local_cs = create :conservation_status, place: place, taxon: species, geoprivacy: Observation::OPEN
          create :identification, observation: o, taxon: species
          o.reload
          expect( o ).not_to be_coordinates_obscured
        end
      end

      describe "when a dissenting ID is of a non-threatened taxon" do
        before { load_test_taxa }
        let( :cs ) { create :conservation_status, taxon: @Calypte_anna }
        let( :o ) { create :observation, taxon: cs.taxon, latitude: 1, longitude: 1 }
        before do
          expect( o.community_taxon ).to be_blank
          create :identification, observation: o, taxon: o.taxon
          o.reload
          expect( o.community_taxon ).to eq cs.taxon
          expect( o ).to be_coordinates_obscured
        end
        it "should not reveal the coordinates" do
          create :identification, observation: o, taxon: @Pseudacris_regilla
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
      expect( t.observations_count ).to eq( 0 )
      o.update( taxon: t, editing_user_id: o.user_id )
      Delayed::Job.find_each( &:invoke_job )
      t.reload
      expect( t.observations_count ).to eq( 1 )
    end

    it "should increment the taxon's ancestors' counter caches" do
      o = Observation.make!
      p = without_delay { Taxon.make!( rank: Taxon::GENUS ) }
      t = without_delay { Taxon.make!( parent: p, rank: Taxon::SPECIES ) }
      expect( p.observations_count ).to eq 0
      o.update( taxon: t, editing_user_id: o.user_id )
      Delayed::Job.find_each( &:invoke_job )
      p.reload
      expect( p.observations_count ).to eq 1
      Observation.elastic_index!( ids: [o.id], delay: true )
      p.reload
      expect( p.observations_count ).to eq 1
    end

    it "should decrement the taxon's counter cache" do
      t = Taxon.make!
      o = without_delay { Observation.make!( taxon: t ) }
      t.reload
      expect( t.observations_count ).to eq( 1 )
      o = without_delay { o.update( taxon: nil, editing_user_id: o.user_id ) }
      t.reload
      expect( t.observations_count ).to eq( 0 )
    end

    it "should decrement the taxon's ancestors' counter caches" do
      p = Taxon.make!( rank: Taxon::GENUS )
      t = Taxon.make!( parent: p, rank: Taxon::SPECIES )
      o = without_delay { Observation.make!( taxon: t ) }
      p.reload
      expect( p.observations_count ).to eq( 1 )
      o = without_delay { o.update( taxon: nil, editing_user_id: o.user_id ) }
      p.reload
      expect( p.observations_count ).to eq( 0 )
    end

    it "should not update a listed taxon stats" do
      t = Taxon.make!
      u = User.make!
      l = List.make!( user: u )
      lt = ListedTaxon.make!( list: l, taxon: t )
      expect( lt.first_observation ).to be_blank
      without_delay { Observation.make!( taxon: t, user: u, observed_on_string: "2014-03-01" ) }
      without_delay { Observation.make!( taxon: t, user: u, observed_on_string: "2015-03-01" ) }
      lt.reload
      expect( lt.first_observation ).to be_blank
      expect( lt.last_observation ).to be_blank
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
      expect( user.observations_count ).to eq old_count - 1
    end

    it "should not queue a DJ job to refresh lists" do
      Delayed::Job.delete_all
      stamp = Time.now
      Observation.make!( taxon: Taxon.make! )
      jobs = Delayed::Job.where( "created_at >= ?", stamp )
      expect( jobs.select {| j | j.handler =~ /List.*refresh_with_observation/m } ).to be_blank
    end

    it "should delete associated updates" do
      subscriber = User.make!
      user = User.make!
      Subscription.make!( user: subscriber, resource: user )
      o = Observation.make( user: user )
      without_delay { o.save! }
      expect( UpdateAction.unviewed_by_user_from_query( subscriber.id, resource: user ) ).to eq true
      o.destroy
      expect( UpdateAction.unviewed_by_user_from_query( subscriber.id, resource: user ) ).to eq false
    end

    it "should delete associated project observations" do
      po = make_project_observation
      o = po.observation
      o.destroy
      expect( ProjectObservation.find_by_id( po.id ) ).to be_blank
    end

    it "should decrement the taxon's counter cache" do
      t = Taxon.make!
      o = without_delay { Observation.make!( taxon: t ) }
      t.reload
      expect( t.observations_count ).to eq 1
      o.destroy
      Delayed::Job.find_each( &:invoke_job )
      t.reload
      expect( t.observations_count ).to eq 0
    end

    it "should decrement the taxon's ancestors' counter caches" do
      p = Taxon.make!( rank: Taxon::GENUS )
      t = Taxon.make!( parent: p, rank: Taxon::SPECIES )
      o = without_delay { Observation.make!( taxon: t ) }
      p.reload
      expect( p.observations_count ).to eq( 1 )
      o.destroy
      Delayed::Job.find_each( &:invoke_job )
      p.reload
      expect( p.observations_count ).to eq( 0 )
    end

    it "should create a deleted observation" do
      o = Observation.make!
      o.destroy
      deleted_obs = DeletedObservation.where( observation_id: o.id ).first
      expect( deleted_obs ).not_to be_blank
      expect( deleted_obs.user_id ).to eq o.user_id
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
end
