require File.expand_path("../../spec_helper", __FILE__)

describe ObservationsExportFlowTask do
  it { is_expected.to validate_presence_of :user_id }

  elastic_models( Observation, Identification )
  describe "validation" do
    it "should not allow exports of more than 200,000 observations" do
      ft = ObservationsExportFlowTask.make
      allow( ft ).to receive(:observations_count).and_return( 300000 )
      ft.inputs.build( extra: { query: "photos=true" } )
      expect( ft ).not_to be_valid
    end
    it "should not allow a new export if an existing one has not run yet" do
      ft = make_observations_export_flow_task
      expect( ft ).to be_valid
      extra_ft = ObservationsExportFlowTask.make( user: ft.user )
      extra_ft.inputs.build( extra: { query: "photos=true" } )
      expect( extra_ft ).not_to be_valid
    end
    it "should allow a new export if an existing one has not run yet but has an error" do
      ft = make_observations_export_flow_task( error: "something went terribly wrong" )
      expect( ft ).to be_valid
      extra_ft = ObservationsExportFlowTask.make( user: ft.user )
      extra_ft.inputs.build( extra: { query: "photos=true" } )
      expect( extra_ft ).to be_valid
    end
  end
  describe "run" do
    it "should not work if the task is not saved" do
      make_default_site
      o = Observation.make!
      ft = ObservationsExportFlowTask.make
      ft.inputs.build(:extra => {:query => "user_id=#{o.user_id}"})
      ft.run #( debug: true, logger: Logger.new( STDOUT ) )
      expect( ft.outputs ).to be_blank
      expect( ft.exception ).not_to be_blank
    end
    # Note: we *should* test raising an error when the task is deleted
    # mid-run, but I'm not sure how to do that in a single process. ~~~kueda
    # 202108
    describe "user_id filter" do
      before do
        # not sure why the before(:each) in spec_helper may not have run yet here
        make_default_site
        @o = Observation.make!
        @ft = ObservationsExportFlowTask.make
        @ft.inputs.build(:extra => {:query => "user_id=#{@o.user_id}"})
        @ft.save!
        @ft.run
      end
      it "should generate a zipped csv archive by default" do
        output = @ft.outputs.first
        expect(output).not_to be_blank
        expect(output.file.path).to be =~ /csv.zip$/
      end
      it "should work" do
        csv = CSV.open(File.join(@ft.work_path, "#{@ft.basename}.csv")).to_a
        expect(csv.size).to eq 2
        expect(csv[1]).to include @o.id.to_s
      end
    end

    it "should filter by year" do
      u = User.make!
      o2004 = Observation.make!(:observed_on_string => "2004-05-02", :user => u)
      expect(o2004.observed_on.year).to eq 2004
      o2010 = Observation.make!(:observed_on_string => "2010-05-02", :user => u)
      expect(o2010.observed_on.year).to eq 2010
      expect(Observation.by(u).on("2010")).not_to be_blank
      ft = ObservationsExportFlowTask.make
      ft.inputs.build(:extra => {:query => "user_id=#{u.id}&year=2010"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect(csv[1]).to include o2010.id.to_s
    end

    it "should filter by week" do
      u = User.make!
      o1 = Observation.make!(:observed_on_string => "2010-05-01", :user => u)
      o2 = Observation.make!(:observed_on_string => "2010-05-02", :user => u)
      ft = ObservationsExportFlowTask.make
      ft.inputs.build(:extra => {:query => "user_id=#{u.id}&week=17"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 3
      expect(csv[1]).to include o1.id.to_s
      expect(csv[2]).to include o2.id.to_s
    end

    it "should filter by without_taxon_id" do
      u = User.make!
      o_of_taxon = Observation.make!( user: u, taxon: Taxon.make! )
      o_of_other_taxon = Observation.make!( user: u, taxon: Taxon.make! )
      expect( u.observations.count ).to eq 2
      ft = ObservationsExportFlowTask.make
      ft.inputs.build( extra: { query: "user_id=#{u.id}&without_taxon_id=#{o_of_taxon.taxon.id}" } )
      ft.save!
      ft.run #( debug: true, logger: Logger.new( STDOUT ) )
      csv = CSV.open( File.join( ft.work_path, "#{ft.basename}.csv" ) ).to_a
      expect( csv.size ).to eq 2
      taxon_id_col_idx = csv[0].index( "taxon_id" )
      expect( csv.detect{|row| row[taxon_id_col_idx].to_i == o_of_taxon.taxon.id } ).to be_blank
      expect( csv.detect{|row| row[taxon_id_col_idx].to_i == o_of_other_taxon.taxon.id } ).not_to be_blank
    end

    it "should filter by not_in_place" do
      u = User.make!
      place = make_place_with_geom
      o_in_place = Observation.make!( user: u, latitude: place.latitude, longitude: place.longitude )
      o_not_in_place = Observation.make!( user: u, latitude: place.latitude + 10, longitude: place.longitude + 10 )
      expect( u.observations.count ).to eq 2
      ft = ObservationsExportFlowTask.make
      ft.inputs.build( extra: { query: "user_id=#{u.id}&not_in_place=#{place.id}" } )
      ft.save!
      ft.run
      csv = CSV.open( File.join( ft.work_path, "#{ft.basename}.csv" ) ).to_a
      expect( csv.size ).to eq 2
      id_col_idx = csv[0].index( "id" )
      expect( csv.detect {| row | row[id_col_idx].to_i == o_in_place.id } ).to be_blank
      expect( csv.detect {| row | row[id_col_idx].to_i == o_not_in_place.id } ).not_to be_blank
    end

    it "should allow JSON output" do
      o = Observation.make!
      ft = ObservationsExportFlowTask.make
      ft.options = {:format => "json"}
      ft.inputs.build(:extra => {:query => "user_id=#{o.user_id}"})
      ft.save!
      ft.run
      output = ft.outputs.first
      expect(output).not_to be_blank
      expect(output.file.path).to be =~ /json.zip$/
      expect {
        JSON.parse( File.open( File.join( ft.work_path, "#{ft.basename}.json" ) ).read )
      }.not_to raise_error
    end

    it "should filter by project" do
      u = User.make!
      po = make_project_observation
      in_project = po.observation
      not_in_project = Observation.make!
      ft = ObservationsExportFlowTask.make
      ft.inputs.build(:extra => {:query => "projects%5B%5D=#{po.project.slug}"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect( csv.detect{|row| row.detect{|v| v == in_project.id.to_s}} ).not_to be_blank
      expect( csv.detect{|row| row.detect{|v| v == not_in_project.id.to_s}} ).to be_blank
    end

    describe "email notification" do
      let(:o) { create :observation }
      let(:ft) {
        ft = build :observations_export_flow_task
        ft.inputs.build( extra: { query: "user_id=#{o.user.id}" } )
        ft.save!
        ft
      }
      it "should happen if requested" do
        ft.update( options: { email: true } )
        expect {
          ft.run
        }.to change( ActionMailer::Base.deliveries, :size ).by 1
      end
      it "should not happen if not requested" do
        expect( ft.options[:email] ).to be_blank
        expect {
          ft.run
        }.not_to change( ActionMailer::Base.deliveries, :size )
      end
    end
  end

  describe "geoprivacy" do
    elastic_models( UpdateAction )

    it "should not include private coordinates you can't see" do
      o = make_private_observation(:taxon => Taxon.make!)
      viewer = User.make!
      ft = ObservationsExportFlowTask.make(:user => viewer)
      ft.inputs.build(:extra => {:query => "taxon_id=#{o.taxon_id}"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect(csv[1]).not_to include o.private_latitude.to_s
    end

    it "should include private coordinates if viewing your own observations" do
      o = make_private_observation(:taxon => Taxon.make!)
      viewer = o.user
      ft = ObservationsExportFlowTask.make(:user => viewer)
      ft.inputs.build(:extra => {:query => "user_id=#{o.user_id}"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect(csv[1]).to include o.private_latitude.to_s
    end

    it "should include private coordinates if viewing a project you curate" do
      o = make_private_observation(:taxon => Taxon.make!)
      po = make_project_observation(:observation => o, :user => o.user)
      p = po.project
      pu = without_delay do
        ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR)
      end
      viewer = pu.user
      ft = ObservationsExportFlowTask.make(:user => viewer)
      ft.inputs.build(:extra => {:query => "projects[]=#{p.id}"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect(csv[1]).to include o.private_latitude.to_s
    end

    it "should not include private coordinates if viewing a project you curate but don't have curator_coordinate_access" do
      o = make_private_observation(:taxon => Taxon.make!)
      po = ProjectObservation.make!(:observation => o)
      p = po.project
      pu = without_delay do
        ProjectUser.make!(:project => p, :role => ProjectUser::CURATOR)
      end
      viewer = pu.user
      expect( po ).not_to be_prefers_curator_coordinate_access
      expect( o ).not_to be_coordinates_viewable_by(viewer)
      ft = ObservationsExportFlowTask.make(:user => viewer)
      ft.inputs.build(:extra => {:query => "projects[]=#{p.id}"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect(csv[1]).not_to include o.private_latitude.to_s
    end

    it "should include obscured coordinates you can see with a place filter even if the obscured coordinates are outside of the place" do
      place = make_place_with_geom
      o = Observation.make!( latitude: 0.99, longitude: 0.99, geoprivacy: Observation::OBSCURED )
      o.latitude = 1.1
      o.longitude = 1.1
      o.set_geom_from_latlon
      Observation.where( id: o.id ).update_all(
        latitude: o.latitude,
        longitude: o.longitude,
        private_latitude: o.private_latitude,
        private_longitude: o.private_longitude,
        geom: o.geom,
        private_geom: o.private_geom
      )
      o.reload
      PlaceDenormalizer.denormalize
      expect( o.public_places ).not_to include place
      expect( o.places ).to include place
      ft = ObservationsExportFlowTask.make(
        user: o.user
      )
      expect( o ).to be_coordinates_viewable_by( ft.user )
      ft.inputs.build( extra: { query: "place_id=#{place.id}&user_id=#{o.user.id}" } )
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect(csv[1]).to include o.private_latitude.to_s
    end

    describe "for collection projects" do
      let(:place) { make_place_with_geom }
      let(:user) { make_user_with_privilege( UserPrivilege::ORGANIZER ) }
      let(:project) {
        p = Project.make!(
          project_type: "collection",
          user: user,
          prefers_user_trust: true,
          created_at: 2.weeks.ago,
          updated_at: 2.weeks.ago
        )
        p.project_observation_rules.create( operator: "observed_in_place?", operand: place )
        p.update_attribute( :observation_requirements_updated_at, 2.weeks.ago )
        p
      }
      def stub_api_requests_for_observation( o, options = {} )
        Delayed::Worker.new.work_off
        PlaceDenormalizer.denormalize
        es_o = Observation.elastic_search( where: { id: o.id } ).results[0]
        # make sure it's indexed
        expect( es_o.id.to_i ).to eq o.id
        # When you specify a project, the export will use the API, so we're
        # stubbing the API response here
        # This stubs the first request
        stub_request(:get, /\/v1\/observations\?.*id_above=1[^\d]/).
          to_return(
            status: 200,
            body: {
              total_results: options[:obs_not_in_project] ? 0 : 1,
              page: 1,
              per_page: 1,
              results: options[:obs_not_in_project] ? [] : [
                { id: o.id }
              ],
              test: "stub working for first request"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        # This stubs second and subsequent requests
        stub_request(:get, /\/v1\/observations\?.*id_above=[2-9]/).
          to_return(
            status: 200,
            body: {
              total_results: 1,
              page: 2,
              per_page: 1,
              results: [],
              test: "stub working for second request"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        stub_request(:get, /\/v1\/observations\?.*per_page=1[^0]/).
          to_return(
            status: 200,
            body: {
              total_results: options[:obs_not_in_project] ? 0 : 1,
              page: 1,
              per_page: 1,
              results: options[:obs_not_in_project] ? [] : [
                { id: o.id }
              ],
              test: "stub working for total_entries request"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
        # stub the request to get collection project membership
        stub_request(:get, /\/v1\/observations\/#{o.id}\?.*include_new_projects/).
          to_return(
            status: 200,
            body: {
              total_results: options[:obs_not_in_project] ? 0 : 1,
              page: 1,
              per_page: 1,
              results: options[:obs_not_in_project] ? [] : [
                {
                  id: o.id,
                  non_traditional_projects: options[:coordinates_not_viewable] ? [] : [
                    project: {
                      id: project.id
                    }
                  ]
                }
              ],
              test: "stub working for second request"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end
      def export_csv_for_project( p )
        ft = ObservationsExportFlowTask.make( user: p.user )
        ft.inputs.build( extra: { query: "projects[]=#{p.id}" })
        ft.save!
        ft.run #( debug: true, logger: Logger.new( STDOUT ) )
        f = CSV.open( File.join( ft.work_path, "#{ft.basename}.csv" ) )
        csv = f.to_a
        f.close
        csv
      end
      it "should include private coordinates if the observer trusts you with anything" do
        pu = ProjectUser.make!(
          project: project,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_ANY
        )
        o = Observation.make!(
          user: pu.user,
          latitude: place.latitude,
          longitude: place.longitude,
          geoprivacy: Observation::PRIVATE
        )
        stub_api_requests_for_observation( o )
        csv = export_csv_for_project( project)
        expect( csv.size ).to eq 2
        expect( csv[1] ).to include o.private_latitude.to_s
      end
      it "should include private coordinates if the observer trusts you with threatened taxa and the observed taxon is threatened" do
        pu = ProjectUser.make!(
          project: project,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_TAXON
        )
        o = Observation.make!(
          user: pu.user,
          latitude: place.latitude,
          longitude: place.longitude,
          taxon: make_threatened_taxon
        )
        stub_api_requests_for_observation( o )
        csv = export_csv_for_project( project )
        expect( csv.size ).to eq 2
        expect( csv[1] ).to include o.private_latitude.to_s
      end
      it "should not include private coordinates if the observer trusts you with threatened taxa and the observed taxon is threatened and geoprivacy is obscured" do
        pu = ProjectUser.make!(
          project: project,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_TAXON
        )
        o = Observation.make!(
          user: pu.user,
          latitude: place.latitude,
          longitude: place.longitude,
          taxon: make_threatened_taxon,
          geoprivacy: Observation::OBSCURED
        )
        stub_api_requests_for_observation( o, coordinates_not_viewable: true )
        csv = export_csv_for_project( project )
        expect( csv.size ).to eq 2
        expect( csv[1] ).not_to include o.private_latitude.to_s
      end
      it "should not include private coordinates if the observation is not in the project" do
        pu = ProjectUser.make!(
          project: project,
          prefers_curator_coordinate_access_for: ProjectUser::CURATOR_COORDINATE_ACCESS_FOR_TAXON
        )
        o = Observation.make!(
          user: pu.user,
          latitude: place.latitude + 10,
          longitude: place.longitude + 10,
          geoprivacy: Observation::OBSCURED
        )
        stub_api_requests_for_observation( o, obs_not_in_project: true )
        csv = export_csv_for_project( project )
        expect( csv.size ).to eq 1
        expect( csv.to_s ).not_to include o.private_latitude.to_s
      end
      it "should not include private coordinates if the observer is not in the project" do
        o = Observation.make!(
          latitude: place.latitude,
          longitude: place.longitude,
          geoprivacy: Observation::PRIVATE
        )
        stub_api_requests_for_observation( o, coordinates_not_viewable: true )
        csv = export_csv_for_project( project)
        expect( csv.size ).to eq 2
        expect( csv[1] ).not_to include o.private_latitude.to_s
      end
    end

    it "should include private coordinates if the observer trusts the exporter" do
      o = make_private_observation( taxon: create( :taxon ) )
      viewer = create :user
      Friendship.make!( user: o.user, friend: viewer, trust: true )
      expect( o ).to be_coordinates_viewable_by( viewer )
      ft = ObservationsExportFlowTask.make( user: viewer )
      ft.inputs.build( extra: { query: "user_id=#{o.user_id}" } )
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect( csv.size ).to eq 2
      expect( csv[1] ).to include o.private_latitude.to_s
    end
  end

  describe "columns" do
    it "should be configurable such that just the first column is included" do
      o = Observation.make!( taxon: Taxon.make! )
      ft = ObservationsExportFlowTask.make( options: { columns: Observation::CSV_COLUMNS[0..0] } )
      ft.inputs.build( extra: { query: "taxon_id=#{o.taxon_id}" } )
      ft.save!
      ft.run
      csv = CSV.open( File.join( ft.work_path, "#{ft.basename}.csv" ) ).to_a
      expect( csv[0].size ).to eq 1
    end

    it "should be configurable such that all columns are included" do
      o = Observation.make!( taxon: Taxon.make! )
      ft = ObservationsExportFlowTask.make( options: { columns: Observation::CSV_COLUMNS } )
      ft.inputs.build( extra: { query: "taxon_id=#{o.taxon_id}" } )
      ft.save!
      ft.run
      csv = CSV.open( File.join( ft.work_path, "#{ft.basename}.csv" ) ).to_a
      expect( csv[0].size ).to eq Observation::CSV_COLUMNS.size
      expect( csv[1].size ).to eq Observation::CSV_COLUMNS.size
      Observation::CSV_COLUMNS.each do | column |
        expect( csv[0] ).to include column
      end
    end

    it "should never include anything but allowed columns" do
      ft = ObservationsExportFlowTask.make(:options => {:columns => %w(delete destroy badness)})
      ft.inputs.build(:extra => {:query => "user_id=1"})
      ft.save!
      expect(ft.export_columns).to be_blank
    end
  end

  describe "ident_by columns" do
    it "should get taxon name by user login" do
      i = Identification.make!
      ft = ObservationsExportFlowTask.make( options: { columns: ["id", "ident_by_#{i.user.login}:taxon_name"] } )
      ft.inputs.build( extra: { query: "taxon_id=#{i.taxon_id}" } )
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect( csv.size ).to eq 2
      expect( csv[1][1] ).to eq i.taxon.name
    end
  end

  describe "ident_user_id filter" do
    it "should only include obs identified by the user" do
      i = Identification.make!
      Observation.make!( taxon: i.taxon )
      ident_column = "ident_by_#{i.user.login}:taxon_name"
      ft = ObservationsExportFlowTask.make(
        options: { columns: ["id", ident_column] }
      )
      ft.inputs.build( extra: { query: "taxon_id=#{i.taxon_id}&ident_user_id=#{i.user_id}" } )
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect( csv.size ).to eq 2
      expect( csv[0][1] ).to eq ident_column
      expect( csv[1][0].to_i ).to eq i.observation_id
      expect( csv[1][1] ).to eq i.taxon.name
    end
  end

  describe "user_name column" do
    it "should have a value if the observer set a name" do
      o = create :observation, user: create( :user, name: "Balthazar" )
      ft = ObservationsExportFlowTask.make( options: { columns: %w(user_name) } )
      ft.inputs.build( extra: { query: "user_id=#{o.user.id}" } )
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      user_name_index = csv[0].index( "user_name" )
      expect( csv[1][user_name_index] ).not_to be_blank
      expect( csv[1][user_name_index] ).to eq o.user.name
    end
  end
end
