require File.expand_path("../../spec_helper", __FILE__)

describe ObservationsExportFlowTask do
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

    it "should filter by user_id" do
      csv = CSV.open(File.join(@ft.work_path, "#{@ft.basename}.csv")).to_a
      expect(csv.size).to eq 2
      expect(csv[1]).to include @o.id.to_s
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

    it "should allow JSON output" do
      ft = ObservationsExportFlowTask.make
      ft.options = {:format => "json"}
      ft.inputs.build(:extra => {:query => "user_id=#{@o.user_id}"})
      ft.save!
      ft.run
      output = ft.outputs.first
      expect(output).not_to be_blank
      expect(output.file.path).to be =~ /json.zip$/
      expect {
        JSON.parse(open(File.join(ft.work_path, "#{ft.basename}.json")).read)
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
  end

  describe "columns" do
    it "should be configurable" do
      o = Observation.make!(:taxon => Taxon.make!)
      ft = ObservationsExportFlowTask.make(:options => {:columns => Observation::CSV_COLUMNS[0..0]})
      ft.inputs.build(:extra => {:query => "taxon_id=#{o.taxon_id}"})
      ft.save!
      ft.run
      csv = CSV.open(File.join(ft.work_path, "#{ft.basename}.csv")).to_a
      expect(csv[0].size).to eq 1
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
end
