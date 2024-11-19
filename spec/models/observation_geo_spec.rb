# frozen_string_literal: true

require "#{File.dirname( __FILE__ )}/../spec_helper.rb"

describe Observation do
  before( :all ) do
    DatabaseCleaner.clean_with( :truncation, except: %w(spatial_ref_sys) )
  end

  elastic_models( Observation, Taxon )

  describe "private location data" do
    let( :original_place_guess ) { "place of unquenchable secrecy" }
    let( :original_latitude ) { 38.1234 }
    let( :original_longitude ) { -122.1234 }
    let( :cs ) { ConservationStatus.make! }
    let( :defaults ) do
      {
        taxon: cs.taxon,
        latitude: original_latitude,
        longitude: original_longitude,
        place_guess: original_place_guess
      }
    end

    it "should be set automatically if the taxon is threatened" do
      observation = Observation.make!( defaults )
      expect( observation.taxon ).to be_threatened
      expect( observation.private_longitude ).not_to be_blank
      expect( observation.private_longitude ).not_to eq observation.longitude
      expect( observation.place_guess ).to eq Observation.place_guess_from_latlon(
        observation.latitude, observation.longitude, acc: observation.public_positional_accuracy
      )
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
        observation.latitude, observation.longitude, acc: observation.public_positional_accuracy
      )
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
      ].each do | place_guess |
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
      expect(
        po.project_user.preferred_curator_coordinate_access
      ).to eq ProjectUser::CURATOR_COORDINATE_ACCESS_OBSERVER
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

    it "should not be visible to managers of projects to which the observation has been " \
      "added if the observer is not a member" do
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
      o.update( geoprivacy: Observation::PRIVATE, latitude: 1, longitude: 1 )
      expect( o ).to be_coordinates_private
      pu = ProjectUser.make!( project: po.project, role: ProjectUser::MANAGER )
      expect( o.coordinates_viewable_by?( pu.user ) ).to be true
    end

    it "should not remove private_place_guess when an identificaiton gets added" do
      original_place_guess = "the secret place"
      o = Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::PRIVATE,
        place_guess: original_place_guess )
      expect( o.private_place_guess ).to eq original_place_guess
      Identification.make!( observation: o )
      o.reload
      expect( o.private_place_guess ).to eq original_place_guess
    end

    describe "curator_coordinate_access_for" do
      let( :place ) { make_place_with_geom }
      let( :project ) do
        proj = Project.make( :collection )
        proj.update( prefers_user_trust: true )
        ProjectUser.make!(
          project: proj,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
        )
        proj.project_observation_rules << ProjectObservationRule.new( operator: "observed_in_place?", operand: place )
        proj.reload
        proj
      end
      let( :non_curator ) do
        u = ProjectUser.make!( project: project ).user
        u.reload
        u
      end
      let( :curator ) do
        u = ProjectUser.make!( project: project, role: ProjectUser::CURATOR ).user
        u.reload
        u
      end
      def stub_api_response_for_observation( observation )
        response_json = <<-JSON
          {
            "results": [
              {
                "id": #{observation.id},
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
        stub_request( :get, /#{INatAPIService::ENDPOINT}/ ).to_return(
          status: 200,
          body: response_json,
          headers: { "Content-Type" => "application/json" }
        )
      end
      let( :o ) do
        Observation.make!( latitude: place.latitude, longitude: place.longitude, taxon: make_threatened_taxon )
      end
      it "should not allow curator access by default" do
        ProjectUser.make!( project: project, user: o.user )
        stub_api_response_for_observation( o )
        expect( o ).to be_in_collection_projects( [project] )
        expect( o ).to be_coordinates_obscured
        expect( o.coordinates_viewable_by?( curator ) ).to be false
      end
      it "should not allow curator access if the project observation requirements changed during the wait period" do
        expect(
          project.observation_requirements_updated_at
        ).to be > ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
        ProjectUser.make!(
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
        allow_any_instance_of( Project ).to receive( :observation_requirements_updated_at ).
          and_return( ( ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD + 1.week ).ago )
        expect(
          project.observation_requirements_updated_at
        ).to be < ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
        ProjectUser.make!(
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
        let( :pu ) do
          ProjectUser.make!(
            project: project,
            user: o.user,
            prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_TAXON
          )
        end
        before do
          allow_any_instance_of( Project ).to receive( :observation_requirements_updated_at ).
            and_return( ( ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD + 1.week ).ago )
          expect(
            project.observation_requirements_updated_at
          ).to be < ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
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
        let( :pu ) do
          ProjectUser.make!(
            project: project,
            user: o.user,
            prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
          )
        end
        before do
          allow_any_instance_of( Project ).to receive( :observation_requirements_updated_at ).
            and_return( ( ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD + 1.week ).ago )
          expect(
            project.observation_requirements_updated_at
          ).to be < ProjectUser::CURATOR_COORDINATE_ACCESS_WAIT_PERIOD.ago
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
      expect( o.latitude ).to be_blank
      o.obscure_coordinates
      expect( o.latitude ).to be_blank
      expect( o.private_latitude ).to be_blank
      expect( o.longitude ).to be_blank
      expect( o.private_longitude ).to be_blank
    end

    it "should not affect already obscured coordinates" do
      o = create :observation, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED
      lat = o.latitude
      private_lat = o.private_latitude
      expect( o ).to be_coordinates_obscured
      o.obscure_coordinates
      o.reload
      expect( o.latitude.to_f ).to eq lat.to_f
      expect( o.private_latitude.to_f ).to eq private_lat.to_f
    end

    it "should not affect already obscured coordinates of a protected taxon" do
      o = create :observation, latitude: 1, longitude: 1, taxon: create( :taxon, :threatened )
      lat = o.latitude
      private_lat = o.private_latitude
      expect( o ).to be_coordinates_obscured
      o.geoprivacy = Observation::OBSCURED
      o.obscure_coordinates
      expect( o.latitude.to_f ).to eq lat.to_f
      expect( o.private_latitude.to_f ).to eq private_lat.to_f
    end
  end

  describe "unobscure_coordinates" do
    stub_elastic_index! Observation

    it "should work" do
      true_lat = 38.0
      true_lon = -122.0
      o = create :observation, latitude: true_lat, longitude: true_lon, taxon: create( :taxon, :threatened )
      expect( o ).to be_coordinates_obscured
      expect( o.latitude.to_f ).not_to eq true_lat
      expect( o.longitude.to_f ).not_to eq true_lon
      o.unobscure_coordinates
      expect( o ).not_to be_coordinates_obscured
      expect( o.latitude.to_f ).to eq true_lat
      expect( o.longitude.to_f ).to eq true_lon
    end

    it "should not affect observations without coordinates" do
      o = build_stubbed :observation
      expect( o.latitude ).to be_blank
      o.unobscure_coordinates
      expect( o.latitude ).to be_blank
      expect( o.private_latitude ).to be_blank
      expect( o.longitude ).to be_blank
      expect( o.private_longitude ).to be_blank
    end

    it "should not unobscure observations with obscured geoprivacy" do
      o = create :observation, latitude: 38, longitude: -122, geoprivacy: Observation::OBSCURED
      o.unobscure_coordinates
      expect( o ).to be_coordinates_obscured
    end

    it "should not unobscure observations with private geoprivacy" do
      o = create :observation, latitude: 38, longitude: -122, geoprivacy: Observation::PRIVATE
      o.unobscure_coordinates
      expect( o ).to be_coordinates_obscured
      expect( o.latitude ).to be_blank
    end

    it "should reset public_positional_accuracy" do
      o = create :observation, latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED, positional_accuracy: 5
      expect( o.public_positional_accuracy ).not_to eq o.positional_accuracy
      # unobscure_coordinates should be impossible if geoprivacy gets set
      o.geoprivacy = nil
      o.unobscure_coordinates
      # public_positional_accuracy only gets reset after saving
      o.save
      expect( o.public_positional_accuracy ).to eq o.positional_accuracy
    end
  end

  describe "geoprivacy" do
    stub_elastic_index! Observation

    let( :geoprivacy ) { Observation::PRIVATE }
    let( :latitude ) { 37 }
    let( :longitude ) { -122 }
    let( :taxon ) { build :taxon }

    subject do
      create :observation,
        taxon: taxon,
        latitude: latitude,
        longitude: longitude,
        geoprivacy: geoprivacy,
        place_guess: "Duluth, MN"
    end

    context "when geoprivacy private" do
      it { is_expected.to be_coordinates_obscured }

      it "should remove public coordinates" do
        expect( subject.latitude ).to be_blank
        expect( subject.longitude ).to be_blank
      end

      it "should remove place_guess" do
        expect( subject.place_guess ).to be_blank
      end

      it "should remove public coordinates if coords change but not geoprivacy" do
        subject.update latitude: 1, longitude: 1

        expect( subject ).to be_coordinates_obscured
        expect( subject.latitude ).to be_blank
        expect( subject.longitude ).to be_blank
      end

      it "should restore public coordinates when removing geoprivacy" do
        expect( subject.latitude ).to be_blank
        expect( subject.longitude ).to be_blank
        subject.update geoprivacy: nil
        expect( subject.latitude.to_f ).to eq latitude
        expect( subject.longitude.to_f ).to eq longitude
      end
    end

    context "when geoprivacy obscured" do
      let( :geoprivacy ) { Observation::OBSCURED }
      let( :threatened_taxon ) { create :taxon, :threatened }

      it { is_expected.to be_coordinates_obscured }

      it "should remove public coordinates when moving to private" do
        expect( subject.latitude ).not_to be_blank
        expect( subject.longitude ).not_to be_blank
        subject.update geoprivacy: Observation::PRIVATE
        expect( subject.latitude ).to be_blank
        expect( subject.longitude ).to be_blank
      end

      context "with threatened taxon" do
        let( :taxon ) { create :taxon, :threatened }

        it "should not unobscure observations of threatened taxa" do
          expect( subject ).to be_coordinates_obscured
          subject.update geoprivacy: nil
          expect( subject.geoprivacy ).to be_blank
          expect( subject ).to be_coordinates_obscured
        end
      end
    end

    context "when geoprivacy not obscured or private" do
      let( :geoprivacy ) { "open" }

      it "should be nil " do
        expect( subject.geoprivacy ).to be_nil
      end

      it "should remove place_guess from to_plain_s when geoprivacy updated" do
        original_place_guess = subject.place_guess
        expect( subject.to_plain_s ).to match /#{original_place_guess}/
        subject.update geoprivacy: Observation::OBSCURED
        expect( subject.to_plain_s ).not_to match /#{original_place_guess}/
        expect( subject.private_place_guess ).not_to be_blank
      end

      context "with threatened taxon" do
        let( :taxon ) { create :taxon, :threatened }

        it "should remove public coordinates when made private" do
          expect( subject ).to be_coordinates_obscured
          expect( subject.latitude ).not_to be_blank
          subject.update geoprivacy: Observation::PRIVATE
          expect( subject.latitude ).to be_blank
          expect( subject.longitude ).to be_blank
        end
      end
    end

    it "should set public coordinates to something other than the private coordinates " \
      "when going from private to obscured" do
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
    let!( :observation ) { create :observation }

    before { allow( observation ).to receive( :set_geom_from_latlon ) }

    it "gets called on save" do
      observation.run_callbacks :save

      expect( observation ).to have_received :set_geom_from_latlon
    end
  end

  describe "geom" do
    let( :observation ) { build :observation, latitude: latitude, longitude: longitude }
    let( :latitude ) { 1 }
    let( :longitude ) { 1 }

    before { observation.set_geom_from_latlon }

    context "with coords" do
      it "should be set" do
        expect( observation.geom ).not_to be_blank
      end

      it "should change" do
        expect( observation.geom.y ).to eq 1.0
        observation.latitude = 2
        observation.set_geom_from_latlon
        expect( observation.geom.y ).to eq 2.0
      end

      it "should go away" do
        expect( observation.geom ).to_not be_blank
        observation.assign_attributes latitude: nil, longitude: nil
        observation.set_geom_from_latlon
        expect( observation.geom ).to be_blank
      end
    end

    context "without coords" do
      let( :latitude ) { nil }
      let( :longitude ) { nil }

      it "should not be set" do
        expect( observation.geom ).to be_blank
      end
    end
  end

  describe "private_geom" do
    let( :observation ) { build :observation, latitude: latitude, longitude: longitude, geoprivacy: geoprivacy }
    let( :geoprivacy ) { nil }
    let( :latitude ) { 1 }
    let( :longitude ) { 1 }

    before { observation.set_geom_from_latlon }

    context "with coords" do
      it "should be set" do
        expect( observation.private_geom ).not_to be_blank
      end

      it "should change" do
        expect( observation.private_geom.y ).to eq 1.0
        observation.assign_attributes latitude: 2
        observation.set_geom_from_latlon
        expect( observation.private_geom.y ).to eq 2.0
      end

      it "should go away" do
        expect( observation.private_geom ).not_to be_blank
        observation.assign_attributes latitude: nil, longitude: nil
        observation.set_geom_from_latlon
        expect( observation.private_geom ).to be_blank
      end

      context "and with geoprivacy" do
        let( :geoprivacy ) { Observation::OBSCURED }

        prepend_before { observation.reassess_coordinate_obscuration }

        it "should be set" do
          expect( observation.latitude ).not_to eq 1.0
          expect( observation.private_latitude ).to eq 1.0
          expect( observation.geom.y ).not_to eq 1.0
          expect( observation.private_geom.y ).to eq 1.0
        end
      end

      context "and without geoprivacy" do
        it "should be set" do
          expect( observation.latitude ).to eq 1.0
          expect( observation.private_geom.y ).to eq 1.0
        end
      end
    end

    context "without coords" do
      let( :latitude ) { nil }
      let( :longitude ) { nil }

      it "should not be set" do
        expect( observation.private_geom ).to be_blank
      end
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
      w = lat_lon_distance_in_meters( p.swlat, p.swlng, p.swlat, p.nelng )
      h = lat_lon_distance_in_meters( p.swlat, p.swlng, p.nelat, p.swlng )
      d = [w, h].min
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude, positional_accuracy: d / 2 )
      expect( o.places ).to include p
    end
    it "should not include places that don't contain positional_accuracy circle" do
      p = make_place_with_geom
      w = lat_lon_distance_in_meters( p.swlat, p.swlng, p.swlat, p.nelng )
      h = lat_lon_distance_in_meters( p.swlat, p.swlng, p.nelat, p.swlng )
      d = [w, h].max
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude, positional_accuracy: d * 2 )
      expect( o.places ).not_to include p
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
      let( :o ) { Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED ) }
      let( :uncertainty_cell_center_latlon ) { Observation.uncertainty_cell_center_latlon( o.latitude, o.longitude ) }
      let( :half_cell ) { Observation::COORDINATE_UNCERTAINTY_CELL_SIZE / 2 }
      let( :uncertainty_cell_ne_latlon ) { uncertainty_cell_center_latlon.map {| c | ( c + half_cell ).to_f } }
      let( :uncertainty_cell_sw_latlon ) { uncertainty_cell_center_latlon.map {| c | ( c - half_cell ).to_f } }
      it "should match the obscuration cell corners when positional_accuracy is blank" do
        expect( o.positional_accuracy ).to be_blank
        expect( o.ne_latlon.map( &:to_f ) ).to eq uncertainty_cell_ne_latlon
        expect( o.sw_latlon.map( &:to_f ) ).to eq uncertainty_cell_sw_latlon
      end
      it "should match the positional_accuracy bounding box corners when positional_accuracy is greater " \
        "than the obscuration cell" do
        o.update( positional_accuracy: 100_000 )
        o.reload
        positional_accuracy_degrees = (
          o.positional_accuracy.to_i / ( 2 * Math::PI * Observation::PLANETARY_RADIUS ) * 360.0
        )
        positional_accuracy_ne_latlon = [
          o.latitude + positional_accuracy_degrees,
          o.longitude + positional_accuracy_degrees
        ].map( &:to_f )
        positional_accuracy_sw_latlon = [
          o.latitude - positional_accuracy_degrees,
          o.longitude - positional_accuracy_degrees
        ].map( &:to_f )
        expect( o.ne_latlon.map( &:to_f ) ).to eq positional_accuracy_ne_latlon
        expect( o.sw_latlon.map( &:to_f ) ).to eq positional_accuracy_sw_latlon
      end
    end
  end

  describe "reassess_coordinates_for_observations_of" do
    it "should obscure coordinates for observations of threatened taxa" do
      t = Taxon.make!
      o = Observation.make!( taxon: t, latitude: 1, longitude: 1 )
      ConservationStatus.make!( taxon: t )
      expect( o ).not_to be_coordinates_obscured
      Observation.reassess_coordinates_for_observations_of( t )
      o.reload
      expect( o ).to be_coordinates_obscured
    end

    it "should obscure coordinates for observations with dissenting identifications of threatened taxa" do
      load_test_taxa
      o = make_research_grade_observation( taxon: @Calypte_anna )
      2.times { Identification.make!( observation: o, taxon: @Calypte_anna ) }
      Identification.make!( observation: o, taxon: @Pseudacris_regilla )
      expect( o ).not_to be_coordinates_obscured
      ConservationStatus.make!( taxon: @Pseudacris_regilla )
      Delayed::Worker.new.work_off
      o.reload
      Observation.reassess_coordinates_for_observations_of( @Pseudacris_regilla )
      o.reload
      expect( o ).to be_coordinates_obscured
    end

    it "should not unobscure coordinates of obs of unthreatened if geoprivacy is set" do
      t = Taxon.make!
      o = Observation.make!( latitude: 1, longitude: 1, geoprivacy: Observation::OBSCURED, taxon: t )
      old_lat = o.latitude
      expect( o ).to be_coordinates_obscured
      Observation.reassess_coordinates_for_observations_of( t )
      o.reload
      expect( o ).to be_coordinates_obscured
      expect( o.latitude ).to eq( old_lat )
    end

    it "should change the place_guess" do
      p = make_place_with_geom( admin_level: Place::COUNTRY_LEVEL )
      t = Taxon.make!
      place_guess = "somewhere awesome"
      o = Observation.make!( taxon: t, latitude: p.latitude, longitude: p.longitude, place_guess: place_guess )
      ConservationStatus.make!( taxon: t )
      Observation.reassess_coordinates_for_observations_of( t )
      o.reload
      expect( o.place_guess ).not_to be =~ /#{place_guess}/
      expect( o.place_guess ).to be =~ /#{p.name}/
    end
  end

  describe "mappable" do
    stub_elastic_index! Observation, Taxon

    describe "on save" do
      let!( :observation ) { create :observation }

      it "updates mappable" do
        allow( observation ).to receive( :update_mappable )
        observation.run_callbacks :save
        expect( observation ).to have_received :update_mappable
      end

      it "calculates mappable" do
        allow( observation ).to receive( :calculate_mappable )
        observation.run_callbacks :save
        expect( observation ).to have_received :calculate_mappable
      end
    end

    describe "#calculate_mappable" do
      let( :observation ) { build_stubbed :observation, latitude: lat, longitude: lon }
      let( :lat ) { 1.1 }
      let( :lon ) { 2.2 }

      context "without lat/lon" do
        let( :lat ) { nil }
        let( :lon ) { nil }

        it { expect( observation.calculate_mappable ).to be false }
      end

      context "with lat/lon" do
        it { expect( observation.calculate_mappable ).to be true }

        it "should not be mappable with a terrible accuracy" do
          observation.assign_attributes( public_positional_accuracy: observation.uncertainty_cell_diagonal_meters + 1 )
          expect( observation.calculate_mappable ).to be false
        end
      end

      context "when adding captive metric" do
        let( :observation ) do
          build_stubbed :observation,
            :with_quality_metric,
            metric: QualityMetric::WILD,
            latitude: lat,
            longitude: lon
        end

        it "should be mappable" do
          expect( observation.calculate_mappable ).to be true
        end
      end

      context "with an inaccurate location" do
        let( :observation ) do
          build_stubbed :observation,
            :with_quality_metric,
            metric: QualityMetric::LOCATION,
            latitude: lat,
            longitude: lon
        end

        it { expect( observation.calculate_mappable ).to be false }

        it "should be mappable when location metric is deleted" do
          expect( observation.calculate_mappable ).to be false
          observation.quality_metrics.reset
          expect( observation.calculate_mappable ).to be true
        end
      end

      context "when captive" do
        let( :observation ) { build_stubbed :observation, latitude: lat, longitude: lon, captive: true }

        it { expect( observation.calculate_mappable ).to be true }
      end

      context "when obscured" do
        let( :observation ) { build_stubbed :observation, :research_grade, geoprivacy: Observation::OBSCURED }

        it { expect( observation.calculate_mappable ).to be true }
      end

      context "when threatened taxa" do
        let( :threatened_taxon ) { build_stubbed :taxon, :threatened }
        let( :observation ) { build_stubbed :observation, latitude: lat, longitude: lon, taxon: threatened_taxon }

        it { expect( observation.calculate_mappable ).to be true }
      end

      context "when it's not evidence of an organism" do
        let( :observation ) do
          build_stubbed :observation, :research_grade, :with_quality_metric, metric: QualityMetric::EVIDENCE
        end

        it { expect( observation.calculate_mappable ).to be false }
      end

      context "when it's flagged" do
        let( :observation ) { build_stubbed :observation, :research_grade, :with_flag, flag: Flag::SPAM }

        it { expect( observation.calculate_mappable ).to be false }
      end
    end

    describe "with a photo" do
      it "should not be mappable if its photo is flagged" do
        o = create :observation, :research_grade
        expect( o.mappable? ).to be true
        create :flag, flaggable: o.observation_photos.first.photo, flag: Flag::SPAM
        o.reload
        expect( o.mappable? ).to be false
      end
    end

    it "should not be mappable if community disagrees with taxon" do
      t = create :taxon, :as_species
      u = create :user, prefers_community_taxa: false
      o = create :observation, :research_grade, user: u
      5.times { create :identification, observation: o, taxon: t }
      o.reload
      expect( o.taxon ).not_to eq t
      expect( o.community_taxon ).to eq t
      expect( o.mappable? ).to be false
    end

    it "should be mappable if the community taxon contains the taxon" do
      genus = create :taxon, :as_genus
      species = create :taxon, :as_species, parent: genus
      o = make_research_grade_candidate_observation( taxon: genus )
      create :identification, observation: o, taxon: species
      expect( o.taxon ).to eq species
      expect( o.community_taxon ).to eq genus
      expect( o ).to be_mappable
    end
  end

  describe "coordinate transformation", focus: true do
    let( :proj4_nztm ) do
      "+proj=tmerc +lat_0=0 +lon_0=173 +k=0.9996 +x_0=1600000 +y_0=10000000 +ellps=GRS80 " \
        "+towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
    end
    subject { Observation.make }

    # FIXME: this is fragile
    it "requires coordinate_system to be valid" do
      subject.coordinate_system = "some_invalid_value"
      subject.valid?
      expect( subject.errors[:coordinate_system].size ).to eq( 1 )
    end

    it "sets lat lng" do
      subject.geo_y = 5_413_457.7
      subject.geo_x = 1_528_677.3
      subject.coordinate_system = proj4_nztm
      subject.save!
      expect( subject.latitude ).to be_within( 0.0000001 ).of( -41.4272781531 )
      expect( subject.longitude ).to be_within( 0.0000001 ).of( 172.1464131267 )
    end
  end

  describe "observations_places" do
    it "should generate observations_places after save" do
      p = make_place_with_geom
      o = Observation.make!
      expect( o.observations_places.length ).to eq 0
      expect( ObservationsPlace.exists?( observation_id: o.id, place_id: p.id ) ).to be false
      o.latitude = p.latitude
      o.longitude = p.longitude
      o.save
      o.reload
      expect( o.observations_places.length ).to be >= 1
      expect( ObservationsPlace.exists?( observation_id: o.id, place_id: p.id ) ).to be true
    end

    it "deletes its observations_places on destroy" do
      p = make_place_with_geom
      o = Observation.make!( latitude: p.latitude, longitude: p.longitude )
      expect( ObservationsPlace.exists?( observation_id: o.id, place_id: p.id ) ).to be true
      o.destroy
      expect( ObservationsPlace.exists?( observation_id: o.id, place_id: p.id ) ).to be false
    end
  end

  describe "interpolate_coordinates" do
    it "should use means" do
      u = User.make!
      Observation.make!( user: u, latitude: 1, longitude: 1, observed_on_string: "2014-06-02 00:00",
        positional_accuracy: 100 )
      Observation.make!( user: u, latitude: 2, longitude: 2, observed_on_string: "2014-06-02 02:00",
        positional_accuracy: 100 )
      o = Observation.make!( user: u, observed_on_string: "2014-06-02 01:00" )
      o.interpolate_coordinates
      expect( o.latitude ).to eq 1.5
      expect( o.longitude ).to eq 1.5
    end

    it "should use weight by time" do
      u = User.make!
      Observation.make!( user: u, latitude: 1, longitude: 1, observed_on_string: "2014-06-02 00:00",
        positional_accuracy: 100 )
      Observation.make!( user: u, latitude: 2, longitude: 2, observed_on_string: "2014-06-02 02:00",
        positional_accuracy: 100 )
      o = Observation.make!( user: u, observed_on_string: "2014-06-02 01:59" )
      o.interpolate_coordinates
      expect( o.latitude.to_f ).to be > 1.5
      expect( o.longitude.to_f ).to be > 1.5
    end
  end

  describe "random_neighbor_lat_lon", disabled: ENV["TRAVIS_CI"] do
    it "randomizes values within a 0.2 degree square" do
      lat_lons = [[0, 0], [0.001, 0.001], [0.199, 0.199]]
      values = []
      100.times do
        lat_lons.each do | ll |
          rand_ll = Observation.random_neighbor_lat_lon( ll[0], ll[1] )
          # random values should be in range
          expect( rand_ll[0] ).to be_between( 0, 0.2 )
          expect( rand_ll[1] ).to be_between( 0, 0.2 )
          # values should be different from their original
          expect( rand_ll[0] ).not_to be( ll[0] )
          expect( rand_ll[1] ).not_to be( ll[1] )
          values += rand_ll
        end
      end
      average = values.inject( :+ ) / values.size.to_f
      # we expect the center of the cluster to be around 0.1, 0.1
      expect( average ).to be_between( 0.095, 0.105 )
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
